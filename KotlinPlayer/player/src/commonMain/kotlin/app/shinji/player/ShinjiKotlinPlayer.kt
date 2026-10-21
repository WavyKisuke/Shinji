package app.shinji.player

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.IconButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/** Nuvio-style player overlay. Native iOS/MPV owns the actual video surface. */
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
    var panel by remember { mutableStateOf<PlayerPanel?>(null) }

    Box(Modifier.fillMaxSize().background(Color.Black)) {
        Row(
            Modifier.fillMaxWidth().align(Alignment.TopCenter).padding(14.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBack) { Text("‹", color = Color.White) }
            Text(state.title, color = Color.White, maxLines = 1, modifier = Modifier.weight(1f).padding(horizontal = 12.dp))
            IconButton(onClick = onSettings) { Text("⚙", color = Color.White) }
        }

        Row(
            Modifier.align(Alignment.Center),
            horizontalArrangement = Arrangement.spacedBy(34.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = { onSeek(-10_000) }, modifier = Modifier.size(56.dp)) { Text("−10", color = Color.White) }
            IconButton(onClick = onPlayPause, modifier = Modifier.size(68.dp)) {
                Text(if (state.isPlaying) "Ⅱ" else "▶", color = Color.White)
            }
            IconButton(onClick = { onSeek(10_000) }, modifier = Modifier.size(56.dp)) { Text("+10", color = Color.White) }
        }

        Row(
            Modifier.fillMaxWidth().align(Alignment.BottomCenter).padding(horizontal = 18.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(formatTime(state.positionMs), color = Color.White)
            Slider(
                value = if (state.durationMs > 0) state.positionMs.toFloat() / state.durationMs else 0f,
                onValueChange = { onSeek((it.coerceIn(0f, 1f) * state.durationMs).toLong()) },
                modifier = Modifier.weight(1f).padding(horizontal = 10.dp),
            )
            Text(formatTime(state.durationMs), color = Color.White)
        }

        Row(
            Modifier.align(Alignment.BottomEnd).padding(end = 18.dp, bottom = 58.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            PlayerAction(if (state.isMuted) "Unmute" else "Mute") { onMute() }
            PlayerAction("Audio") { panel = PlayerPanel.AUDIO }
            PlayerAction("Subs") { panel = PlayerPanel.SUBTITLES }
            PlayerAction("${state.playbackRate}x") { panel = PlayerPanel.SPEED }
        }
    }

    when (panel) {
        PlayerPanel.AUDIO -> TrackDialog("Audio", state.audioTracks, state.selectedAudioId, onDismiss = { panel = null }) {
            onAudioSelected(it)
            panel = null
        }
        PlayerPanel.SUBTITLES -> TrackDialog("Subtitles", state.subtitleTracks, state.selectedSubtitleId, onDismiss = { panel = null }, allowNone = true) {
            onSubtitleSelected(it)
            panel = null
        }
        PlayerPanel.SPEED -> SpeedDialog(state.playbackRate, onDismiss = { panel = null }) {
            onPlaybackRateSelected(it)
            panel = null
        }
        null -> Unit
    }
}

enum class PlayerPanel { AUDIO, SUBTITLES, SPEED }

data class PlayerTrack(val id: String, val label: String, val language: String? = null)
data class ShinjiPlayerState(
    val title: String,
    val positionMs: Long,
    val durationMs: Long,
    val isPlaying: Boolean,
    val isMuted: Boolean,
    val playbackRate: Float = 1f,
    val audioTracks: List<PlayerTrack> = emptyList(),
    val subtitleTracks: List<PlayerTrack> = emptyList(),
    val selectedAudioId: String? = null,
    val selectedSubtitleId: String? = null,
)

@Composable
private fun PlayerAction(label: String, onClick: () -> Unit) {
    Text(
        label,
        color = Color.White,
        modifier = Modifier.background(Color.Black.copy(alpha = 0.55f)).clickable(onClick = onClick).padding(horizontal = 10.dp, vertical = 7.dp),
    )
}

@Composable
private fun TrackDialog(
    title: String,
    tracks: List<PlayerTrack>,
    selectedId: String?,
    onDismiss: () -> Unit,
    allowNone: Boolean = false,
    onSelected: (PlayerTrack?) -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            LazyColumn(Modifier.widthIn(min = 240.dp, max = 360.dp)) {
                if (allowNone) item {
                    Text("None", modifier = Modifier.fillMaxWidth().clickable { onSelected(null) }.padding(14.dp))
                }
                items(tracks, key = { it.id }) { track ->
                    Column(Modifier.fillMaxWidth().clickable { onSelected(track) }.padding(14.dp)) {
                        Text(track.label)
                        track.language?.let { Text(it) }
                        if (track.id == selectedId) Text("Selected")
                    }
                }
                if (tracks.isEmpty()) item { Text("No tracks available", modifier = Modifier.padding(14.dp)) }
            }
        },
        confirmButton = {},
    )
}

@Composable
private fun SpeedDialog(current: Float, onDismiss: () -> Unit, onSelected: (Float) -> Unit) {
    val speeds = listOf(0.5f, 0.75f, 1f, 1.25f, 1.5f, 1.75f, 2f)
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Playback speed") },
        text = {
            LazyColumn(Modifier.widthIn(min = 200.dp, max = 320.dp)) {
                items(speeds) { speed ->
                    Text("${speed}x${if (speed == current) "  •" else ""}", modifier = Modifier.fillMaxWidth().clickable { onSelected(speed) }.padding(14.dp))
                }
            }
        },
        confirmButton = {},
    )
}

private fun formatTime(ms: Long): String {
    val total = (ms / 1000).coerceAtLeast(0)
    return "%d:%02d".format(total / 60, total % 60)
}
