package com.rgservice.carlauncher.core

import android.content.Context
import android.util.AttributeSet

/**
 * Reproduce los videos del holograma (res/raw) sin sonido.
 * play(entrada, bucle): reproduce la entrada una vez y después el bucle sin fin.
 * play(0, bucle): solo el bucle. play(video, 0, onEnd): una sola vez y avisa al terminar.
 */
class HoloVideoView @JvmOverloads constructor(ctx: Context, attrs: AttributeSet? = null) :
    android.view.TextureView(ctx, attrs), android.view.TextureView.SurfaceTextureListener {

    private var surface: android.view.Surface? = null
    private var mp: android.media.MediaPlayer? = null
    private var inRes = 0
    private var loopRes = 0
    private var onEnd: (() -> Unit)? = null
    private var playingRes = 0

    init {
        surfaceTextureListener = this
        isOpaque = false
    }

    fun play(entry: Int, loop: Int, end: (() -> Unit)? = null) {
        if (entry == 0 && loop != 0 && loop == playingRes && mp != null) return // ya está en ese bucle
        inRes = entry; loopRes = loop; onEnd = end
        if (surface != null) startSequence()
    }

    fun stop() {
        inRes = 0; loopRes = 0; onEnd = null
        releasePlayer()
    }

    private fun startSequence() {
        if (inRes != 0) {
            playRes(inRes, false) {
                if (loopRes != 0) playRes(loopRes, true, null) else onEnd?.invoke()
            }
        } else if (loopRes != 0) playRes(loopRes, true, null)
    }

    private fun playRes(res: Int, looping: Boolean, done: (() -> Unit)?) {
        val s = surface ?: return
        releasePlayer()
        val m = android.media.MediaPlayer()
        try {
            val afd = resources.openRawResourceFd(res)
            m.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()
            m.setSurface(s)
            m.isLooping = looping
            m.setVolume(0f, 0f)
            m.setOnPreparedListener { it.start() }
            m.setOnCompletionListener { if (!looping) done?.invoke() }
            m.setOnErrorListener { _, _, _ -> done?.invoke(); true }
            m.prepareAsync()
            mp = m
            playingRes = res
        } catch (e: Exception) {
            m.release()
            done?.invoke()
        }
    }

    private fun releasePlayer() {
        try { mp?.setOnCompletionListener(null); mp?.stop() } catch (e: Exception) { }
        try { mp?.release() } catch (e: Exception) { }
        mp = null
        playingRes = 0
    }

    override fun onSurfaceTextureAvailable(st: android.graphics.SurfaceTexture, w: Int, h: Int) {
        surface = android.view.Surface(st)
        if (inRes != 0 || loopRes != 0) startSequence()
    }

    override fun onSurfaceTextureSizeChanged(st: android.graphics.SurfaceTexture, w: Int, h: Int) {}

    override fun onSurfaceTextureDestroyed(st: android.graphics.SurfaceTexture): Boolean {
        releasePlayer()
        surface?.release()
        surface = null
        return true
    }

    override fun onSurfaceTextureUpdated(st: android.graphics.SurfaceTexture) {}

    override fun onDetachedFromWindow() {
        releasePlayer()
        super.onDetachedFromWindow()
    }
}
