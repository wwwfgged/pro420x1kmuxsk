import 'dart:async';
import 'dart:io';

/// Нативний Windows медіа плеєр через персистентний PowerShell процес,
/// який керує System.Windows.Media.MediaPlayer (WPF / Media Foundation).
///
/// ПЕРЕВІРЕНО ТА ПРАЦЮЄ (стандалон тест v3, файловий IPC):
/// - play/pause/resume/seek/stop — всі підтверджені робочими на реальному mp4
/// - MCI (winmm.dll) НЕ використовується — на цій машині відсутній
///   компонент "Windows Media Player Legacy", без якого MCI не працює.
/// - IPC через файли в %TEMP% замість stdin: stdin/Console.In виявився
///   ненадійним (губить дані, конфлікти потоків). Файловий обмін —
///   простий і 100% перевірений робочий патерн.
///
/// Підтримка форматів: mp3, m4a, aac, mp4, wma, wav — надійно (Media
/// Foundation). webm/ogg можуть НЕ працювати (немає вбудованих
/// декодерів Vorbis/Opus).

class WindowsPlayer {
  static Process? _process;
  static Timer? _statusPollTimer;
  static bool _starting = false;
  static Completer<void>? _readyCompleter;

  static bool _isPlaying = false;
  static bool _isPaused = false;
  static Duration _position = Duration.zero;
  static Duration _duration = Duration.zero;

  static late final String _tempDir;
  static late final File _cmdFile;
  static late final File _statusFile;
  static late final File _eventFile;
  static late final File _errFile;
  static late final File _scriptFile;
  static late final File _pidFile;
  static bool _pathsInitialized = false;

  static final _positionController = StreamController<Duration>.broadcast();
  static final _durationController = StreamController<Duration>.broadcast();
  static final _playingController = StreamController<bool>.broadcast();
  static final _completionController = StreamController<void>.broadcast();

  static Stream<Duration> get positionStream => _positionController.stream;
  static Stream<Duration> get durationStream => _durationController.stream;
  static Stream<bool> get playingStream => _playingController.stream;
  static Stream<void> get completionStream => _completionController.stream;

  static bool get isPlaying => _isPlaying;
  static bool get isPaused => _isPaused;
  static Duration get position => _position;
  static Duration get duration => _duration;

  // ===== PowerShell "сервер"-скрипт (перевірений робочий) =====
  static const _psScript = r'''
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$cmdFile    = "$env:TEMP\muzik420_cmd.txt"
$statusFile = "$env:TEMP\muzik420_status.txt"
$eventFile  = "$env:TEMP\muzik420_event.txt"
$errFile    = "$env:TEMP\muzik420_error.log"

foreach ($f in @($cmdFile, $statusFile, $eventFile)) {
    if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
}

function LogErr([string]$where, $err) {
    $msg = "$(Get-Date -Format o) [$where] $($err.ToString())`r`n"
    [System.IO.File]::AppendAllText($errFile, $msg)
}

function WriteAtomic([string]$path, [string]$content) {
    $tmp = "$path.tmp"
    [System.IO.File]::WriteAllText($tmp, $content)
    Move-Item -LiteralPath $tmp -Destination $path -Force
}

$player = New-Object System.Windows.Media.MediaPlayer
$script:isPlaying = $false
$script:isPaused = $false

function WriteStatus {
    $posMs = 0; $durMs = 0
    try {
        if ($player.Source -ne $null) {
            $posMs = [math]::Round($player.Position.TotalMilliseconds)
            if ($player.NaturalDuration.HasTimeSpan) {
                $durMs = [math]::Round($player.NaturalDuration.TimeSpan.TotalMilliseconds)
            }
        }
    } catch {}
    WriteAtomic $statusFile "playing=$($script:isPlaying);paused=$($script:isPaused);pos=$posMs;dur=$durMs"
}

$player.Add_MediaEnded({
    $script:isPlaying = $false
    $script:isPaused = $false
    try { WriteAtomic $eventFile "ENDED" } catch {}
})
$player.Add_MediaFailed({
    param($s, $e)
    try { LogErr "MediaFailed" $e.ErrorException } catch {}
})

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(150)
$timer.Add_Tick({
    if (Test-Path $cmdFile) {
        try {
            $lines = @(Get-Content -LiteralPath $cmdFile -ErrorAction Stop)
            Remove-Item -LiteralPath $cmdFile -Force -ErrorAction SilentlyContinue

            foreach ($line in $lines) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                $sp = $line.IndexOf(' ')
                if ($sp -ge 0) {
                    $cmd = $line.Substring(0, $sp)
                    $arg = $line.Substring($sp + 1)
                } else {
                    $cmd = $line
                    $arg = ''
                }
                try {
                    switch ($cmd) {
                        'PLAY' {
                            $player.Stop()
                            $player.Open([Uri]::new($arg))
                            $player.Play()
                            $script:isPlaying = $true
                            $script:isPaused = $false
                        }
                        'PAUSE' {
                            $player.Pause()
                            $script:isPlaying = $false
                            $script:isPaused = $true
                        }
                        'RESUME' {
                            $player.Play()
                            $script:isPlaying = $true
                            $script:isPaused = $false
                        }
                        'STOP' {
                            $player.Stop()
                            $player.Close()
                            $script:isPlaying = $false
                            $script:isPaused = $false
                        }
                        'SEEK' {
                            $ms = [double]::Parse($arg, [System.Globalization.CultureInfo]::InvariantCulture)
                            $player.Position = [TimeSpan]::FromMilliseconds($ms)
                        }
                        'EXIT' {
                            $player.Stop()
                            $timer.Stop()
                            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
                        }
                    }
                } catch {
                    LogErr "CMD $cmd" $_
                }
            }
        } catch {
            # Файл ще пишеться (race) — спробуємо наступного тіку через 150мс
        }
    }
    try { WriteStatus } catch { LogErr "WriteStatus" $_ }
})
$timer.Start()
WriteStatus
[System.Windows.Threading.Dispatcher]::Run()
''';

  // ===== Внутрішній стан статусу =====

  static bool _lastEndedHandled = true;

  static void _initPaths() {
    if (_pathsInitialized) return;
    _tempDir = Directory.systemTemp.path;
    _cmdFile = File('$_tempDir\\muzik420_cmd.txt');
    _statusFile = File('$_tempDir\\muzik420_status.txt');
    _eventFile = File('$_tempDir\\muzik420_event.txt');
    _errFile = File('$_tempDir\\muzik420_error.log');
    _scriptFile = File('$_tempDir\\muzik420_player.ps1');
    _pidFile = File('$_tempDir\\muzik420_player.pid');
    _pathsInitialized = true;
  }

  /// Якщо попередній запуск додатку закрився без виклику dispose()
  /// (наприклад, вікно закрили без обробки onWindowClose), PowerShell
  /// процес міг лишитись "сиротою" й досі тримати ті самі файли в %TEMP%.
  /// Новий процес почав би з ним конфліктувати за ті самі cmd/status
  /// файли — саме це й спричиняло "не запускається / не перемотує"
  /// після закриття вікна без зупинки музики. Тому примусово вбиваємо
  /// будь-який попередній процес за збереженим PID перед стартом нового.
  static Future<void> _killOrphanProcess() async {
    if (!_pidFile.existsSync()) return;
    try {
      final pidStr = _pidFile.readAsStringSync().trim();
      final pid = int.tryParse(pidStr);
      if (pid != null) {
        print('[WindowsPlayer] 🧹 Знайдено PID попереднього процесу ($pid), вбиваю...');
        try {
          Process.killPid(pid, ProcessSignal.sigkill);
        } catch (_) {}
        // Даємо ОС трохи часу звільнити файли
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (_) {
    } finally {
      try {
        _pidFile.deleteSync();
      } catch (_) {}
    }
  }

  static Future<void> _ensureStarted() async {
    _initPaths();
    if (_process != null) return;
    if (_starting) {
      await _readyCompleter?.future;
      return;
    }

    _starting = true;
    _readyCompleter = Completer<void>();

    try {
      await _killOrphanProcess();

      // Чистий старт
      for (final f in [_cmdFile, _statusFile, _eventFile, _errFile]) {
        if (f.existsSync()) f.deleteSync();
      }

      await _scriptFile.writeAsString(_psScript);

      _process = await Process.start(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy', 'Bypass',
          '-File', _scriptFile.path,
        ],
      );

      // Зберігаємо PID, щоб наступний запуск міг прибрати за нами,
      // якщо цей процес закриється некоректно.
      _pidFile.writeAsStringSync('${_process!.pid}');

      // stdout/stderr не використовуються для протоколу (тільки для діагностики)
      _process!.stdout.listen((_) {});
      _process!.stderr.listen((bytes) {
        print('[WindowsPlayer][stderr] ${String.fromCharCodes(bytes)}');
      });

      unawaited(_process!.exitCode.then((code) {
        print('[WindowsPlayer] PowerShell процес завершився (код $code)');
        _process = null;
        _statusPollTimer?.cancel();
        _isPlaying = false;
        _isPaused = false;
        if (!_disposed && !_playingController.isClosed) {
          _playingController.add(false);
        }
        try {
          if (_pidFile.existsSync()) _pidFile.deleteSync();
        } catch (_) {}
      }));

      // Чекаємо на перший status-файл (= процес готовий)
      var waited = 0;
      const step = 100;
      while (!_statusFile.existsSync() && waited < 10000) {
        await Future.delayed(const Duration(milliseconds: step));
        waited += step;
      }
      if (!_statusFile.existsSync()) {
        throw Exception('PowerShell плеєр не запустився вчасно (timeout).');
      }

      _startStatusPolling();
      if (!_readyCompleter!.isCompleted) _readyCompleter!.complete();
      print('[WindowsPlayer] ✅ Плеєр-процес запущено та готовий');
    } catch (e) {
      print('[WindowsPlayer] Помилка запуску процесу: $e');
      _process = null;
      rethrow;
    } finally {
      _starting = false;
    }
  }

  static void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (_disposed) { t.cancel(); return; }
      try {
        if (_statusFile.existsSync()) {
          final s = _statusFile.readAsStringSync();
          _applyStatus(s);
        }
        if (_eventFile.existsSync()) {
          _eventFile.deleteSync();
          _isPlaying = false;
          _isPaused = false;
          if (!_playingController.isClosed) _playingController.add(false);
          if (!_completionController.isClosed) _completionController.add(null);
        }
      } catch (e) {
        // Файл міг бути в процесі перезапису — просто пропускаємо тік
      }
    });
  }

  static void _applyStatus(String raw) {
    if (_disposed) return;
    final map = <String, String>{};
    for (final part in raw.split(';')) {
      final kv = part.split('=');
      if (kv.length == 2) map[kv[0]] = kv[1];
    }
    if (map.isEmpty) return;

    final playing = map['playing'] == 'True';
    final paused = map['paused'] == 'True';
    final posMs = int.tryParse(map['pos'] ?? '') ?? _position.inMilliseconds;
    final durMs = int.tryParse(map['dur'] ?? '') ?? _duration.inMilliseconds;

    if (playing != _isPlaying || paused != _isPaused) {
      _isPlaying = playing;
      _isPaused = paused;
      if (!_playingController.isClosed) _playingController.add(_isPlaying);
    }

    final newPos = Duration(milliseconds: posMs);
    if (newPos != _position) {
      _position = newPos;
      if (!_positionController.isClosed) _positionController.add(_position);
    }

    final newDur = Duration(milliseconds: durMs);
    if (newDur != _duration) {
      _duration = newDur;
      if (!_durationController.isClosed) _durationController.add(_duration);
    }
  }

  static void _sendCmd(String cmd) {
    if (_process == null) {
      print('[WindowsPlayer] Спроба надіслати "$cmd" без запущеного процесу');
      return;
    }
    try {
      final tmp = File('${_cmdFile.path}.tmp');
      tmp.writeAsStringSync(cmd);
      tmp.renameSync(_cmdFile.path);
    } catch (e) {
      print('[WindowsPlayer] Помилка запису команди "$cmd": $e');
    }
  }

  // ===== PUBLIC API =====

  static Future<void> play(String filePath) async {
    await _ensureStarted();
    _position = Duration.zero;
    _duration = Duration.zero;
    final uri = File(filePath).uri.toString();
    _sendCmd('PLAY $uri');
    print('[WindowsPlayer] ▶️ Play: $filePath');
  }

  static Future<void> pause() async {
    if (!_isPlaying) return;
    _sendCmd('PAUSE');
  }

  static Future<void> resume() async {
    if (!_isPaused) return;
    _sendCmd('RESUME');
  }

  static Future<void> stop() async {
    _sendCmd('STOP');
    _position = Duration.zero;
    _positionController.add(Duration.zero);
  }

  static Future<void> seek(Duration position) async {
    _position = position;
    _positionController.add(position);
    _sendCmd('SEEK ${position.inMilliseconds}');
  }

  static bool _disposed = false;

  static void dispose() {
    if (_disposed) return;
    _disposed = true;
    try {
      _sendCmd('EXIT');
      _statusPollTimer?.cancel();
      Future.delayed(const Duration(milliseconds: 300), () {
        _process?.kill();
        _process = null;
        try {
          if (_pidFile.existsSync()) _pidFile.deleteSync();
        } catch (_) {}
      });
      _positionController.close();
      _durationController.close();
      _playingController.close();
      _completionController.close();
      print('[WindowsPlayer] 🔌 Dispose завершено');
    } catch (e) {
      print('[WindowsPlayer] dispose() error: $e');
    }
  }
}
