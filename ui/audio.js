/*
 * Frontier Signal — presentation-layer audio for the HTML shell.
 *
 * Browser audio may not start before a user gesture. The shell therefore
 * preloads no hidden gameplay and creates/resumes one AudioContext only from
 * pointer/keyboard input. Godot remains the sole owner of in-world audio; the
 * handoff below retires this theme before engine.start() can create its bed.
 */
'use strict';

const ASSET_ROOT = new URL('../game/assets/audio/', import.meta.url);
const BUFFER_URLS = Object.freeze({
  theme: new URL('frontier_signal.wav', ASSET_ROOT),
  navigate: new URL('ui_navigate.wav', ASSET_ROOT),
  confirm: new URL('ui_confirm.wav', ASSET_ROOT),
  deploy: new URL('deploy_stinger.wav', ASSET_ROOT),
});
const SCENE_LEVELS = Object.freeze({
  opening: 0.23,
  hero: 0.24,
  hub: 0.28,
  settings: 0.20,
  launch: 0.16,
  handoff: 0,
});
const MASTER_LEVEL = 0.8;

export class ShellAudio {
  constructor({ muted = false, onMutedChange = () => {}, onStateChange = () => {} } = {}) {
    this.muted = Boolean(muted);
    this.onMutedChange = onMutedChange;
    this.onStateChange = onStateChange;
    this.context = null;
    this.master = null;
    this.musicBus = null;
    this.sfxBus = null;
    this.buffers = new Map();
    this.bufferPromises = new Map();
    this.themeSource = null;
    this.retiringMusic = new Set();
    this.activeOneShots = new Set();
    this.unlockPromise = null;
    this.unlocked = false;
    this.supported = Boolean(window.AudioContext || window.webkitAudioContext);
    this.scene = 'opening';
    this.handedOff = false;
    this.lastError = null;

    document.addEventListener('visibilitychange', () => this._visibilityChanged());
    this._emitState();
  }

  snapshot() {
    return {
      supported: this.supported,
      unlocked: this.unlocked,
      muted: this.muted,
      contextState: this.context?.state || 'none',
      scene: this.scene,
      handedOff: this.handedOff,
      loaded: [...this.buffers.keys()].sort(),
      musicPlaying: Boolean(this.themeSource) && !this.muted && this.context?.state === 'running',
      musicVoices: (this.themeSource ? 1 : 0) + this.retiringMusic.size,
      activeOneShots: this.activeOneShots.size,
      lastError: this.lastError,
    };
  }

  _emitState() {
    const state = this.snapshot();
    document.body.dataset.audio = !state.supported
      ? 'unavailable'
      : state.muted
        ? 'muted'
        : state.unlocked
          ? 'ready'
          : 'locked';
    this.onStateChange(state);
  }

  async unlock() {
    if (!this.supported) return false;
    if (this.unlocked && this.context?.state === 'running') {
      if (!this.muted && !this.handedOff) this._startTheme();
      return true;
    }
    if (this.unlockPromise) return this.unlockPromise;

    this.unlockPromise = (async () => {
      try {
        if (!this.context) this._createGraph();
        // This call is reached only by the gesture listeners in shell.js.
        await this.context.resume();
        await Promise.all(Object.keys(BUFFER_URLS).map((name) => this._loadBuffer(name)));
        this.unlocked = this.context.state === 'running';
        this.lastError = null;
        if (this.unlocked && !this.muted && !this.handedOff) this._startTheme();
        this._emitState();
        return this.unlocked;
      } catch (error) {
        this.unlocked = false;
        this.lastError = String(error?.message || error);
        this._emitState();
        return false;
      } finally {
        this.unlockPromise = null;
      }
    })();
    return this.unlockPromise;
  }

  _createGraph() {
    const Context = window.AudioContext || window.webkitAudioContext;
    this.context = new Context({ latencyHint: 'interactive' });
    this.master = this.context.createGain();
    this.musicBus = this.context.createGain();
    this.sfxBus = this.context.createGain();
    this.master.gain.value = this.muted ? 0 : MASTER_LEVEL;
    this.musicBus.gain.value = 0;
    this.sfxBus.gain.value = 0.42;
    this.musicBus.connect(this.master);
    this.sfxBus.connect(this.master);
    this.master.connect(this.context.destination);
  }

  _loadBuffer(name) {
    if (this.buffers.has(name)) return Promise.resolve(this.buffers.get(name));
    if (this.bufferPromises.has(name)) return this.bufferPromises.get(name);
    const promise = (async () => {
      const response = await fetch(BUFFER_URLS[name], { cache: 'force-cache' });
      if (!response.ok) throw new Error(`Audio asset ${name} returned HTTP ${response.status}`);
      const bytes = await response.arrayBuffer();
      const buffer = await this.context.decodeAudioData(bytes);
      this.buffers.set(name, buffer);
      return buffer;
    })();
    this.bufferPromises.set(name, promise);
    promise.catch(() => this.bufferPromises.delete(name));
    return promise;
  }

  setScene(name) {
    if (!Object.hasOwn(SCENE_LEVELS, name)) return;
    this.scene = name;
    this.handedOff = name === 'handoff';
    if (this.handedOff) return;
    if (this.unlocked && !this.muted) this._startTheme();
    this._ramp(this.musicBus?.gain, SCENE_LEVELS[name], 0.24);
    this._emitState();
  }

  _startTheme() {
    if (this.themeSource || !this.unlocked || this.muted || this.handedOff) return;
    // A rapid mute/unmute must not reconnect a fading previous generation.
    for (const source of this.retiringMusic) source.disconnect();
    this.retiringMusic.clear();
    const buffer = this.buffers.get('theme');
    if (!buffer || this.context.state !== 'running') return;
    const source = this.context.createBufferSource();
    source.buffer = buffer;
    source.loop = true;
    source.connect(this.musicBus);
    source.onended = () => {
      if (this.themeSource === source) this.themeSource = null;
      this.retiringMusic.delete(source);
      this._emitState();
    };
    this.themeSource = source;
    this._ramp(this.musicBus.gain, SCENE_LEVELS[this.scene] ?? SCENE_LEVELS.opening, 0.35);
    source.start();
    this._emitState();
  }

  _stopTheme(fadeSeconds = 0.12) {
    const source = this.themeSource;
    if (!source || !this.context) return;
    this.themeSource = null;
    this.retiringMusic.add(source);
    this._ramp(this.musicBus.gain, 0, fadeSeconds);
    try {
      source.stop(this.context.currentTime + fadeSeconds + 0.02);
    } catch {
      this.retiringMusic.delete(source);
    }
    this._emitState();
  }

  async handoff() {
    this.scene = 'handoff';
    this.handedOff = true;
    this._stopTheme(0.12);
    this._emitState();
    // Do not let Godot start its own theme while the shell source is fading.
    if (this.context && this.retiringMusic.size) {
      await new Promise((resolve) => window.setTimeout(resolve, 160));
      // The stop event is normally delivered already. Disconnect as a final
      // guarantee on throttled browsers before engine.start() is allowed.
      for (const source of this.retiringMusic) {
        source.disconnect();
      }
      this.retiringMusic.clear();
    }
    this._emitState();
  }

  async play(name) {
    if (this.muted || !Object.hasOwn(BUFFER_URLS, name) || name === 'theme') return false;
    if (!this.unlocked) {
      // A real pointer/key gesture may still be decoding. Queue its first UI
      // sound, but never create an AudioContext from an untrusted click call.
      if (!this.unlockPromise) return false;
      const ready = await this.unlockPromise;
      if (!ready) return false;
    }
    if (this.muted || this.context.state !== 'running') return false;
    try {
      const buffer = await this._loadBuffer(name);
      const source = this.context.createBufferSource();
      source.buffer = buffer;
      source.connect(this.sfxBus);
      this.activeOneShots.add(source);
      source.onended = () => {
        this.activeOneShots.delete(source);
        source.disconnect();
        this._emitState();
      };
      source.start();
      this._emitState();
      return true;
    } catch (error) {
      this.lastError = String(error?.message || error);
      this._emitState();
      return false;
    }
  }

  setMuted(value) {
    const next = Boolean(value);
    if (next === this.muted) {
      this._emitState();
      return;
    }
    this.muted = next;
    this.onMutedChange(next);
    if (this.master && this.context) this._ramp(this.master.gain, next ? 0 : MASTER_LEVEL, 0.08);
    if (next) {
      this._stopTheme(0.08);
      for (const source of this.activeOneShots) {
        try {
          source.stop();
        } catch {
          /* already ended */
        }
      }
    } else if (this.unlocked && !this.handedOff) {
      this._startTheme();
    }
    this._emitState();
  }

  _ramp(param, target, seconds) {
    if (!param || !this.context) return;
    const now = this.context.currentTime;
    if (typeof param.cancelAndHoldAtTime === 'function') param.cancelAndHoldAtTime(now);
    else {
      const value = param.value;
      param.cancelScheduledValues(now);
      param.setValueAtTime(value, now);
    }
    param.linearRampToValueAtTime(target, now + seconds);
  }

  async _visibilityChanged() {
    if (!this.context || !this.unlocked) return;
    try {
      if (document.hidden && this.context.state === 'running') await this.context.suspend();
      else if (!document.hidden && this.context.state === 'suspended') await this.context.resume();
      this._emitState();
    } catch {
      // A browser may require another gesture after backgrounding. The next
      // pointer/key input calls unlock() again; gameplay is never blocked.
      this.unlocked = false;
      this._emitState();
    }
  }
}
