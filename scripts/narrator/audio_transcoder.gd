class_name AudioTranscoder
extends RefCounted
## Turns audio files Godot cannot decode itself (M4A / AAC, WebM / Opus) into WAV bytes; only the audio is kept (a
## video track is dropped). Godot 4.7 only decodes MP3, Ogg Vorbis and WAV, so such a file is converted once with the platform's own codecs and the
## WAV is cached under `cache_dir`, keyed by the source path, size and modification time (a swapped file is
## converted again). Windows: the built-in Media Foundation transcoder through PowerShell (nothing to install).
## Elsewhere, or when that fails: `ffmpeg` on the PATH. Returns empty bytes when no converter works.

const _WINDOWS_SCRIPT := """param([string]$In, [string]$Out)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$methods = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 }
$asOp = ($methods | Where-Object { $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
$asAction = ($methods | Where-Object { $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncActionWithProgress`1' })[0]
function Await($op, [Type]$t) { $task = $asOp.MakeGenericMethod($t).Invoke($null, @($op)); $task.Wait() | Out-Null; $task.Result }
[void][Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
[void][Windows.Media.Transcoding.MediaTranscoder, Windows.Media.Transcoding, ContentType = WindowsRuntime]
[void][Windows.Media.MediaProperties.MediaEncodingProfile, Windows.Media.MediaProperties, ContentType = WindowsRuntime]
$src = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($In)) ([Windows.Storage.StorageFile])
$dir = Await ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync([IO.Path]::GetDirectoryName($Out))) ([Windows.Storage.StorageFolder])
$dst = Await ($dir.CreateFileAsync([IO.Path]::GetFileName($Out), [Windows.Storage.CreationCollisionOption]::ReplaceExisting)) ([Windows.Storage.StorageFile])
$profile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateWav([Windows.Media.MediaProperties.AudioEncodingQuality]::High)
$prep = Await ((New-Object Windows.Media.Transcoding.MediaTranscoder).PrepareFileTranscodeAsync($src, $dst, $profile)) ([Windows.Media.Transcoding.PrepareTranscodeResult])
if (-not $prep.CanTranscode) { [Console]::Error.WriteLine("cannot transcode: " + $prep.FailureReason); exit 2 }
$asAction.MakeGenericMethod([double]).Invoke($null, @($prep.TranscodeAsync())).Wait() | Out-Null
"""

## Where converted WAVs (and the helper script) are kept.
var cache_dir: String = "user://audio_cache"


func _init(dir: String = "") -> void:
	if dir != "":
		cache_dir = dir


## WAV bytes of `path` (an M4A or WebM), converting it on first use; empty when it cannot be converted.
func to_wav(path: String) -> PackedByteArray:
	var source: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(source):
		return PackedByteArray()
	var size: int = FileAccess.get_size(source)
	var key: String = ("%s|%d|%d" % [source, size, FileAccess.get_modified_time(source)]).md5_text()
	var cached: String = ProjectSettings.globalize_path(cache_dir.path_join(key + ".wav"))
	if FileAccess.file_exists(cached) and FileAccess.get_size(cached) > 0:
		return FileAccess.get_file_as_bytes(cached)
	DirAccess.make_dir_recursive_absolute(cached.get_base_dir())
	if not (_convert_windows(source, cached) or _convert_ffmpeg(source, cached)):
		push_warning("AudioTranscoder: cannot convert %s (no Media Foundation or ffmpeg)" % source)
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(cached)


func _convert_windows(source: String, target: String) -> bool:
	if OS.get_name() != "Windows":
		return false
	var script: String = ProjectSettings.globalize_path(cache_dir.path_join("m4a_to_wav.ps1"))
	if FileAccess.get_file_as_string(script) != _WINDOWS_SCRIPT:
		var file := FileAccess.open(script, FileAccess.WRITE)
		if file == null:
			return false
		file.store_string(_WINDOWS_SCRIPT)
		file.close()
	var out: Array = []
	var code: int = OS.execute("powershell.exe", ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
			"-File", script.replace("/", "\\"), "-In", source.replace("/", "\\"), "-Out", target.replace("/", "\\")],
			out, true)
	return code == 0 and FileAccess.file_exists(target) and FileAccess.get_size(target) > 0


func _convert_ffmpeg(source: String, target: String) -> bool:
	var out: Array = []
	var code: int = OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-i", source, "-vn", "-acodec", "pcm_s16le", target], out, true)
	return code == 0 and FileAccess.file_exists(target) and FileAccess.get_size(target) > 0
