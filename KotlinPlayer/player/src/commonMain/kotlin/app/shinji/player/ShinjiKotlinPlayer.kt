package app.shinji.player

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/** Nuvio-style player surface. Playback is supplied by the native MPV bridge. */
@Composable
fun ShinjiKotlinPlayer(
    state: ShinjiPlayerState,
    onBack: () -> Unit,
    onPlayPause: () -> Unit,
    onSeek: (Long) -> Unit,
    onAudioSelected: (PlayerTrack) -> Unit,
    onSubtitleSelected: (PlayerTrack?) -> Unit,
    onPlaybackRateSelected: (Float) -> Unit,
    onMute: () -> Unit,
    onSettings: () -> Unit,
) {
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        // The actual video surface is hosted by iOS/MPV underneath this Compose overlay.
        Row(Modifier.fillMaxWidth().align(Alignment.TopCenter).padding(14.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            IconButton(onClick = onBack) { Text("‹", color = Color.White, style = MaterialTheme.typography.headlineMedium) }
            Text(state.title, color = Color.White, maxLines = 1, modifier = Modifier.weight(1f).padding(horizontal = 12.dp))
            IconButton(onClick = onSettings) { Text("⋮", color = Color.White, style = MaterialTheme.typography.headlineMedium) }
        }
        Row(Modifier.align(Alignment.Center), horizontalArrangement = Arrangement.spacedBy(36.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = { onSeek(-10_000) }, modifier = Modifier.size(56.dp)) { Text("−10", color = Color.White) }
            IconButton(onClick = onPlayPause, modifier = Modifier.size(68.dp)) { Text(if (state.isPlaying) "Ⅱ" else "▶", color = Color.White) }
            IconButton(onClick = { onSeek(10_000) }, modifier = Modifier.size(56.dp)) { Text("+10", color = Color.White) }
        }
        Row(Modifier.fillMaxWidth().align(Alignment.BottomCenter).padding(horizontal = 18.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(formatTime(state.positionMs), color = Color.White)
            Slider(value = if (state.durationMs > 0) state.positionMs.toFloat() / state.durationMs else 0f, onValueChange = { onSeek((it * state.durationMs).toLong()) }, modifier = Modifier.weight(1f).padding(horizontal = 10.dp))
            Text(formatTime(state.durationMs), color = Color.White)
        }
    }
}

data class PlayerTrack(val id: String, val label: String)
data class ShinjiPlayerState(val title: String, val positionMs: Long, val durationMs: Long, val isPlaying: Boolean, val isMuted: Boolean)

private fun formatTime(ms: Long): String {
    val total = (ms / 1000).coerceAtLeast(0)
    return "%d:%02d".format(total / 60, total % 60)
}
