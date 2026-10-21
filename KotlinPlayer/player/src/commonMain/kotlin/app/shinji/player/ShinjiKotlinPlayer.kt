package app.shinji.player

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * Kotlin/Compose player surface following the Nuvio fork's PlayerScreen contract.
 * Track selection is intentionally exposed as explicit callbacks so the native
 * iOS bridge can map them to the actual playback engine rather than guessing
 * MPV property names in SwiftUI.
 */
data class PlayerTrack(
    val id: String,
    val label: String,
    val language: String? = null,
)

data class ShinjiPlayerState(
    val title: String,
    val audioTracks: List<PlayerTrack> = emptyList(),
    val subtitleTracks: List<PlayerTrack> = emptyList(),
    val selectedAudioId: String? = null,
    val selectedSubtitleId: String? = null,
    val isMuted: Boolean = false,
    val playbackRate: Float = 1f,
    val isPlaying: Boolean = true,
)

@Composable
fun ShinjiKotlinPlayer(
    state: ShinjiPlayerState,
    onBack: () -> Unit,
    onPlayPause: () -> Unit,
    onMute: () -> Unit,
    onAudioSelected: (PlayerTrack) -> Unit,
    onSubtitleSelected: (PlayerTrack?) -> Unit,
    onPlaybackRateSelected: (Float) -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier.fillMaxSize().background(Color.Black),
        contentAlignment = Alignment.BottomCenter,
    ) {
        Text(
            text = state.title,
            color = Color.White,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.align(Alignment.TopStart).padding(20.dp),
        )
        Row(
            modifier = Modifier.fillMaxWidth().padding(20.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBack) { Text("Back", color = Color.White) }
            IconButton(onClick = onPlayPause) { Text(if (state.isPlaying) "Pause" else "Play", color = Color.White) }
            IconButton(onClick = onMute) { Text(if (state.isMuted) "Unmute" else "Mute", color = Color.White) }
            IconButton(onClick = { state.audioTracks.firstOrNull()?.let(onAudioSelected) }) { Text("Audio", color = Color.White) }
            IconButton(onClick = { onSubtitleSelected(state.subtitleTracks.firstOrNull()) }) { Text("Subs", color = Color.White) }
            IconButton(onClick = { onPlaybackRateSelected(if (state.playbackRate == 1f) 1.5f else 1f) }) { Text("${state.playbackRate}x", color = Color.White) }
        }
    }
}
