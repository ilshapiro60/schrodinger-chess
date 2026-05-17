import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'firebase_options.dart';

// ── Ad unit IDs ──────────────────────────────────────────────────────────────
// TODO: replace both values with real AdMob IDs once the app is approved
const _kBannerIdAndroid = 'ca-app-pub-3940256099942544/6300978111'; // test
const _kBannerIdIos     = 'ca-app-pub-3940256099942544/2934735716'; // test
String get _bannerAdUnitId => Platform.isIOS ? _kBannerIdIos : _kBannerIdAndroid;

// Whether Firebase was successfully initialised at startup.
bool _firebaseAvailable = false;

/// True after [MobileAds.instance.initialize] has completed (iOS: only after ATT).
bool _mobileAdsInitialized = false;

Future<void> _requestTrackingConsentIfNeeded() async {
  if (kIsWeb || !Platform.isIOS) return;
  try {
    // UIKit needs a visible window before ATT can present (especially on iPad).
    await Future<void>.delayed(const Duration(milliseconds: 600));
    var status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      status = await AppTrackingTransparency.requestTrackingAuthorization();
    }
  } catch (e, st) {
    assert(() {
      debugPrint('ATT: request failed: $e\n$st');
      return true;
    }());
  }
}

/// Mobile Ads initializes only after ATT on iOS so consent precedes ad SDK setup.
Future<void> _initializeMobileAdsIfNeeded() async {
  if (_mobileAdsInitialized) return;
  if (kIsWeb) {
    await MobileAds.instance.initialize();
    _mobileAdsInitialized = true;
    return;
  }
  if (Platform.isIOS) {
    await _requestTrackingConsentIfNeeded();
  }
  await MobileAds.instance.initialize();
  _mobileAdsInitialized = true;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseAvailable = true;
  } catch (_) {
    // Firebase not yet configured — online mode will be disabled.
  }
  runApp(const SchrodingerChessApp());
}

// ═══════════════════════════════════════════════════════════════════════════════
// Theme system
// ═══════════════════════════════════════════════════════════════════════════════

class ChessTheme {
  final String name;
  final String emoji;
  final Color appBg;
  final Color appBarBg;
  final Color lightSq;
  final Color darkSq;
  final Color selectedSq;
  final Color captureSq;
  final Color shiftLightSq;
  final Color shiftDarkSq;
  final Color validDot;
  final Color shiftIcon;
  final List<Color> accents;
  final Color statusWhiteBg;
  final Color statusBlackBg;
  final Color statusShiftBg;
  final Color statusOverBg;

  const ChessTheme({
    required this.name,
    required this.emoji,
    required this.appBg,
    required this.appBarBg,
    required this.lightSq,
    required this.darkSq,
    required this.selectedSq,
    required this.captureSq,
    required this.shiftLightSq,
    required this.shiftDarkSq,
    required this.validDot,
    required this.shiftIcon,
    required this.accents,
    required this.statusWhiteBg,
    required this.statusBlackBg,
    required this.statusShiftBg,
    required this.statusOverBg,
  });
}

const List<ChessTheme> kThemes = [
  ChessTheme(
    name: 'Midnight Ocean', emoji: '🌊',
    appBg: Color(0xFF0D1321), appBarBg: Color(0xFF162040),
    lightSq: Color(0xFFD6E8F7), darkSq: Color(0xFF1E5799),
    selectedSq: Color(0xFFFFD600), captureSq: Color(0xFFD32F2F),
    shiftLightSq: Color(0xFFE1BEF5), shiftDarkSq: Color(0xFF7B1FA2),
    validDot: Color(0xFF00E676), shiftIcon: Color(0xFFE040FB),
    accents: [Color(0xFF9C27B0), Color(0xFF1976D2), Color(0xFF00ACC1)],
    statusWhiteBg: Color(0xFF1A3A6B), statusBlackBg: Color(0xFF080F1A),
    statusShiftBg: Color(0xFF4A148C), statusOverBg: Color(0xFF1B5E20),
  ),
  ChessTheme(
    name: 'Gothic Crimson', emoji: '🩸',
    appBg: Color(0xFF0C0008), appBarBg: Color(0xFF200010),
    lightSq: Color(0xFFD4B896), darkSq: Color(0xFF7B0000),
    selectedSq: Color(0xFFFFD700), captureSq: Color(0xFFFF1744),
    shiftLightSq: Color(0xFFEDD5C0), shiftDarkSq: Color(0xFF4A0000),
    validDot: Color(0xFFDAA520), shiftIcon: Color(0xFFB8860B),
    accents: [Color(0xFF8B0000), Color(0xFFB8860B), Color(0xFF6B0000)],
    statusWhiteBg: Color(0xFF2A0010), statusBlackBg: Color(0xFF080003),
    statusShiftBg: Color(0xFF5B0000), statusOverBg: Color(0xFF3B0000),
  ),
  ChessTheme(
    name: 'Emerald Forest', emoji: '🌿',
    appBg: Color(0xFF051A0A), appBarBg: Color(0xFF0D2E12),
    lightSq: Color(0xFFD4EDD4), darkSq: Color(0xFF2D6B3A),
    selectedSq: Color(0xFFFFEB3B), captureSq: Color(0xFFE53935),
    shiftLightSq: Color(0xFFC8E6C9), shiftDarkSq: Color(0xFF1B5E20),
    validDot: Color(0xFF69F0AE), shiftIcon: Color(0xFF76FF03),
    accents: [Color(0xFF388E3C), Color(0xFF00695C), Color(0xFF558B2F)],
    statusWhiteBg: Color(0xFF1B3A20), statusBlackBg: Color(0xFF061008),
    statusShiftBg: Color(0xFF004D40), statusOverBg: Color(0xFF1B5E20),
  ),
  ChessTheme(
    name: 'Classic Wood', emoji: '♟️',
    appBg: Color(0xFF2E1C0E), appBarBg: Color(0xFF3D2514),
    lightSq: Color(0xFFF0D9B5), darkSq: Color(0xFFB58863),
    selectedSq: Color(0xFFF6F669), captureSq: Color(0xFFE57373),
    shiftLightSq: Color(0xFFFFCC80), shiftDarkSq: Color(0xFFE65100),
    validDot: Color(0xFF558B2F), shiftIcon: Color(0xFFFF6F00),
    accents: [Color(0xFF8D6E63), Color(0xFFD4A574), Color(0xFF6D4C41)],
    statusWhiteBg: Color(0xFF4E342E), statusBlackBg: Color(0xFF1A0E08),
    statusShiftBg: Color(0xFF4E2700), statusOverBg: Color(0xFF2E7D32),
  ),
  ChessTheme(
    name: 'Purple Night', emoji: '🔮',
    appBg: Color(0xFF0D0520), appBarBg: Color(0xFF180A35),
    lightSq: Color(0xFFE8D4F5), darkSq: Color(0xFF5B2D8E),
    selectedSq: Color(0xFFFFD600), captureSq: Color(0xFFFF5252),
    shiftLightSq: Color(0xFFF3E5F5), shiftDarkSq: Color(0xFF38006B),
    validDot: Color(0xFFE040FB), shiftIcon: Color(0xFFFF80AB),
    accents: [Color(0xFF7B1FA2), Color(0xFF512DA8), Color(0xFFAD1457)],
    statusWhiteBg: Color(0xFF311B5E), statusBlackBg: Color(0xFF08030F),
    statusShiftBg: Color(0xFF6A1B9A), statusOverBg: Color(0xFF880E4F),
  ),
  ChessTheme(
    name: 'Arctic Ice', emoji: '❄️',
    appBg: Color(0xFF0A1520), appBarBg: Color(0xFF102535),
    lightSq: Color(0xFFE8F4FD), darkSq: Color(0xFF4A90C4),
    selectedSq: Color(0xFFFFEB3B), captureSq: Color(0xFFEF5350),
    shiftLightSq: Color(0xFFE0F7FA), shiftDarkSq: Color(0xFF00838F),
    validDot: Color(0xFF80DEEA), shiftIcon: Color(0xFF00E5FF),
    accents: [Color(0xFF00BCD4), Color(0xFF039BE5), Color(0xFF80DEEA)],
    statusWhiteBg: Color(0xFF102535), statusBlackBg: Color(0xFF060E15),
    statusShiftBg: Color(0xFF006064), statusOverBg: Color(0xFF1B5E20),
  ),
];

// ═══════════════════════════════════════════════════════════════════════════════
// App
// ═══════════════════════════════════════════════════════════════════════════════

class SchrodingerChessApp extends StatelessWidget {
  const SchrodingerChessApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Schrödinger Chess',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E5799),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const _AppBootstrap(),
    );
  }
}

/// Shows the game immediately; ATT + Mobile Ads run after the first visible frame on [GameScreen].
class _AppBootstrap extends StatelessWidget {
  const _AppBootstrap();

  @override
  Widget build(BuildContext context) => const GameScreen();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Domain types
// ═══════════════════════════════════════════════════════════════════════════════

enum PieceType  { pawn, rook, knight, bishop, queen, king }
enum PieceColor { white, black }
enum GamePhase  { move, shift, gameOver }
enum GameMode   { twoPlayer, vsAI, online }

typedef _GameConfig = ({GameMode mode, int boardCount});

class Piece {
  final PieceType  type;
  final PieceColor color;
  const Piece(this.type, this.color);

  String get symbol {
    switch (type) {
      case PieceType.king:   return color == PieceColor.white ? '♔' : '♚';
      case PieceType.queen:  return color == PieceColor.white ? '♕' : '♛';
      case PieceType.rook:   return color == PieceColor.white ? '♖' : '♜';
      case PieceType.bishop: return color == PieceColor.white ? '♗' : '♝';
      case PieceType.knight: return color == PieceColor.white ? '♘' : '♞';
      case PieceType.pawn:   return color == PieceColor.white ? '♙' : '♟';
    }
  }
}

class Pos {
  final int level, row, col;
  const Pos(this.level, this.row, this.col);
  @override
  bool operator ==(Object other) =>
      other is Pos && other.level == level && other.row == row && other.col == col;
  @override
  int get hashCode => Object.hash(level, row, col);
}


// ═══════════════════════════════════════════════════════════════════════════════
// Game logic
// ═══════════════════════════════════════════════════════════════════════════════

class Game {
  final int boardCount;
  late final List<List<List<Piece?>>> boards;

  PieceColor currentPlayer = PieceColor.white;
  GamePhase  phase         = GamePhase.move;
  int?       _lastMoveLevel;

  Game({this.boardCount = 3}) {
    boards = List.generate(
      boardCount, (_) => List.generate(8, (_) => List<Piece?>.filled(8, null)),
    );
    _init();
  }

  Game._empty({this.boardCount = 3}) {
    boards = List.generate(
      boardCount, (_) => List.generate(8, (_) => List<Piece?>.filled(8, null)),
    );
  }

  void _init() {
    for (int l = 0; l < boardCount; l++) {
      final b = boards[l];
      b[0] = _backRank(PieceColor.black);
      for (int c = 0; c < 8; c++) { b[1][c] = Piece(PieceType.pawn, PieceColor.black); }
      for (int r = 2; r < 6; r++) { for (int c = 0; c < 8; c++) { b[r][c] = null; } }
      b[7] = _backRank(PieceColor.white);
      for (int c = 0; c < 8; c++) { b[6][c] = Piece(PieceType.pawn, PieceColor.white); }
    }
  }

  static List<Piece?> _backRank(PieceColor color) => [
    Piece(PieceType.rook,   color), Piece(PieceType.knight, color),
    Piece(PieceType.bishop, color), Piece(PieceType.queen,  color),
    Piece(PieceType.king,   color), Piece(PieceType.bishop, color),
    Piece(PieceType.knight, color), Piece(PieceType.rook,   color),
  ];

  Game clone() {
    final g = Game._empty(boardCount: boardCount);
    for (int l = 0; l < boardCount; l++) {
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          g.boards[l][r][c] = boards[l][r][c];
        }
      }
    }
    g.currentPlayer  = currentPlayer;
    g.phase          = phase;
    g._lastMoveLevel = _lastMoveLevel;
    return g;
  }

  // ── Online serialisation ──────────────────────────────────────────────────

  // Boards stored as 3 flat 128-char strings (64 squares × 2 chars each).
  // Firestore does not support nested arrays.
  Map<String, dynamic> toMap() => {
    'boards': List.generate(boardCount, (l) => List.generate(64, (i) =>
        _encodePiece(boards[l][i ~/ 8][i % 8])).join()),
    'boardCount': boardCount,
    'currentPlayer': currentPlayer == PieceColor.white ? 'white' : 'black',
    'phase': phase.name,
    'lastMoveLevel': _lastMoveLevel ?? -1,
  };

  void applyMap(Map<String, dynamic> d) {
    final rawBoards = d['boards'] as List<dynamic>;
    for (int l = 0; l < boardCount; l++) {
      final s = rawBoards[l] as String;
      for (int i = 0; i < 64; i++) {
        boards[l][i ~/ 8][i % 8] = _decodePiece(s.substring(i * 2, i * 2 + 2));
      }
    }
    currentPlayer = d['currentPlayer'] == 'white' ? PieceColor.white : PieceColor.black;
    phase = GamePhase.values.firstWhere((e) => e.name == d['phase']);
    final lml = d['lastMoveLevel'] as int;
    _lastMoveLevel = lml < 0 ? null : lml;
  }

  static String _encodePiece(Piece? p) {
    if (p == null) return '--';
    final c = p.color == PieceColor.white ? 'w' : 'b';
    switch (p.type) {
      case PieceType.pawn:   return '${c}p';
      case PieceType.rook:   return '${c}r';
      case PieceType.knight: return '${c}n';
      case PieceType.bishop: return '${c}b';
      case PieceType.queen:  return '${c}q';
      case PieceType.king:   return '${c}k';
    }
  }

  static Piece? _decodePiece(String s) {
    if (s.isEmpty || s == '--') return null;
    final color = s[0] == 'w' ? PieceColor.white : PieceColor.black;
    switch (s[1]) {
      case 'p': return Piece(PieceType.pawn,   color);
      case 'r': return Piece(PieceType.rook,   color);
      case 'n': return Piece(PieceType.knight, color);
      case 'b': return Piece(PieceType.bishop, color);
      case 'q': return Piece(PieceType.queen,  color);
      case 'k': return Piece(PieceType.king,   color);
      default:  return null;
    }
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  Piece? pieceAt(int l, int r, int c) => boards[l][r][c];

  bool isOwnPiece(int l, int r, int c) {
    final p = boards[l][r][c];
    return p != null && p.color == currentPlayer;
  }

  int _countKings(PieceColor color) {
    int n = 0;
    for (int l = 0; l < boardCount; l++) {
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          final p = boards[l][r][c];
          if (p != null && p.type == PieceType.king && p.color == color) { n++; }
        }
      }
    }
    return n;
  }

  int get whiteKingsCaptured => boardCount - _countKings(PieceColor.black);
  int get blackKingsCaptured => boardCount - _countKings(PieceColor.white);

  static const _boardNames = ['Board 1', 'Board 2', 'Board 3'];

  String get statusText {
    final pl    = currentPlayer == PieceColor.white ? 'White' : 'Black';
    final score = '♔$whiteKingsCaptured  ♚$blackKingsCaptured';
    switch (phase) {
      case GamePhase.move:
        return '$pl\'s move   $score';
      case GamePhase.shift:
        final bn = _lastMoveLevel != null ? ' on ${_boardNames[_lastMoveLevel!]}' : '';
        return '$pl: shift a piece$bn or skip   $score';
      case GamePhase.gameOver:
        return winner ?? 'Game Over';
    }
  }

  String? get winner {
    if (phase != GamePhase.gameOver) return null;
    final w = whiteKingsCaptured, b = blackKingsCaptured;
    if (w > b) return 'White wins  $w–$b kings';
    if (b > w) return 'Black wins  $b–$w kings';
    return 'Draw!';
  }

  // ── Move validation ───────────────────────────────────────────────────────

  List<Pos> validMovesFrom(int level, int row, int col) {
    if (phase != GamePhase.move) return const [];
    final piece = boards[level][row][col];
    if (piece == null || piece.color != currentPlayer) return const [];
    final moves = <Pos>[];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if (_legal(piece, level, row, col, r, c)) { moves.add(Pos(level, r, c)); }
      }
    }
    return moves;
  }

  bool _legal(Piece p, int l, int fr, int fc, int tr, int tc) {
    if (fr == tr && fc == tc) return false;
    if (boards[l][tr][tc]?.color == p.color) return false;
    final dr = tr - fr, dc = tc - fc;
    switch (p.type) {
      case PieceType.pawn:   return _pawnOk(p, l, fr, fc, tr, tc);
      case PieceType.rook:   return (dr == 0 || dc == 0) && _clear(l, fr, fc, tr, tc);
      case PieceType.bishop: return dr.abs() == dc.abs() && _clear(l, fr, fc, tr, tc);
      case PieceType.queen:
        return (dr == 0 || dc == 0 || dr.abs() == dc.abs()) && _clear(l, fr, fc, tr, tc);
      case PieceType.knight:
        return (dr.abs() == 2 && dc.abs() == 1) || (dr.abs() == 1 && dc.abs() == 2);
      case PieceType.king: return dr.abs() <= 1 && dc.abs() <= 1;
    }
  }

  bool _pawnOk(Piece p, int l, int fr, int fc, int tr, int tc) {
    final dir      = p.color == PieceColor.white ? -1 : 1;
    final startRow = p.color == PieceColor.white ?  6 : 1;
    final dr = tr - fr, dc = tc - fc;
    final target = boards[l][tr][tc];
    if (dc == 0 && dr == dir && target == null) { return true; }
    if (dc == 0 && dr == 2 * dir && fr == startRow &&
        target == null && boards[l][fr + dir][fc] == null) { return true; }
    if (dc.abs() == 1 && dr == dir && target != null) { return true; }
    return false;
  }

  bool _clear(int l, int fr, int fc, int tr, int tc) {
    final dr = (tr - fr).sign, dc = (tc - fc).sign;
    int r = fr + dr, c = fc + dc;
    while (r != tr || c != tc) {
      if (boards[l][r][c] != null) return false;
      r += dr; c += dc;
    }
    return true;
  }

  // ── Execution ─────────────────────────────────────────────────────────────

  bool executeMove(int l, int fr, int fc, int tr, int tc) {
    final piece = boards[l][fr][fc];
    if (piece == null || !_legal(piece, l, fr, fc, tr, tc)) return false;
    boards[l][fr][fc] = null;
    boards[l][tr][tc] = piece;
    _checkWin();
    if (phase == GamePhase.gameOver) return true;
    if (piece.type == PieceType.king) {
      _flipPlayer();
    } else {
      _lastMoveLevel = l;
      phase = GamePhase.shift;
    }
    return true;
  }

  int _shiftUp(int l)   => (l + 1) % boardCount;
  int _shiftDown(int l) => (l - 1 + boardCount) % boardCount;

  List<Pos> shiftablePieces() {
    if (phase != GamePhase.shift || _lastMoveLevel == null) return const [];
    final level = _lastMoveLevel!;
    final result = <Pos>[];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = boards[level][r][c];
        if (p != null && p.color == currentPlayer && p.type != PieceType.king) {
          if (boards[_shiftUp(level)][r][c] == null ||
              boards[_shiftDown(level)][r][c] == null) {
            result.add(Pos(level, r, c));
          }
        }
      }
    }
    return result;
  }

  List<int> shiftTargets(int l, int r, int c) {
    if (phase != GamePhase.shift || l != _lastMoveLevel) return const [];
    final seen = <int>{};
    if (boards[_shiftUp(l)][r][c]   == null) seen.add(_shiftUp(l));
    if (boards[_shiftDown(l)][r][c] == null) seen.add(_shiftDown(l));
    return seen.toList();
  }

  bool executeShift(int fl, int r, int c, int tl) {
    if (phase != GamePhase.shift || fl != _lastMoveLevel) return false;
    final p = boards[fl][r][c];
    if (p == null || p.color != currentPlayer || p.type == PieceType.king) return false;
    if (tl < 0 || tl >= boardCount || boards[tl][r][c] != null) return false;
    boards[fl][r][c] = null;
    boards[tl][r][c] = p;
    _endTurn();
    return true;
  }

  void skipShift() { if (phase == GamePhase.shift) _endTurn(); }

  void _endTurn()    { _flipPlayer(); _checkWin(); }
  void _flipPlayer() {
    _lastMoveLevel = null;
    currentPlayer = currentPlayer == PieceColor.white ? PieceColor.black : PieceColor.white;
    phase = GamePhase.move;
  }

  void _checkWin() {
    if (whiteKingsCaptured == boardCount || blackKingsCaptured == boardCount) {
      phase = GamePhase.gameOver;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AI  (minimax + alpha-beta, depth 3)
// ═══════════════════════════════════════════════════════════════════════════════

class _AiTurn {
  final int fl, fr, fc, tr, tc;
  final int? shiftR, shiftC, shiftToL;
  const _AiTurn({
    required this.fl, required this.fr, required this.fc,
    required this.tr, required this.tc,
    this.shiftR, this.shiftC, this.shiftToL,
  });
}

class _ChessAI {
  static const int _depth = 2;
  static const int _rootTurnCap = 36;
  static const int _nodeTurnCap = 20;
  static const Duration _thinkBudget = Duration(seconds: 3);

  static DateTime? _deadline;

  static bool get _timedOut =>
      _deadline != null && !DateTime.now().isBefore(_deadline!);

  /// Minimax search with a time budget; safe on the main isolate (no [Isolate.run]).
  static _AiTurn? bestTurn(Game g) {
    _deadline = DateTime.now().add(_thinkBudget);
    try {
      final turns = _generateTurns(g, cap: _rootTurnCap);
      if (turns.isEmpty) return null;
      _AiTurn? best;
      int bestScore = -999999;
      for (final turn in turns) {
        if (_timedOut) break;
        final score = _minimax(
          _applyTurn(g.clone(), turn),
          _depth - 1,
          -999999,
          999999,
          false,
        );
        if (score > bestScore) {
          bestScore = score;
          best = turn;
        }
      }
      return best ?? turns.first;
    } finally {
      _deadline = null;
    }
  }

  /// Fast legal move when search times out or errors.
  static _AiTurn? fallbackTurn(Game g) {
    final turns = _generateTurns(g, cap: 48);
    if (turns.isEmpty) return null;
    turns.sort((a, b) => _moveOrderScore(g, b).compareTo(_moveOrderScore(g, a)));
    return turns.first;
  }

  static int _minimax(Game g, int depth, int alpha, int beta, bool maximizing) {
    if (_timedOut) return _evaluate(g);
    if (g.phase == GamePhase.gameOver) {
      final w = g.whiteKingsCaptured, b = g.blackKingsCaptured;
      if (b > w) return  90000;
      if (w > b) return -90000;
      return 0;
    }
    if (depth == 0) return _evaluate(g);
    final turns = _generateTurns(g, cap: _nodeTurnCap);
    if (turns.isEmpty) return _evaluate(g);

    if (maximizing) {
      int best = -999999;
      for (final t in turns) {
        if (_timedOut) break;
        final v = _minimax(_applyTurn(g.clone(), t), depth - 1, alpha, beta, false);
        if (v > best) best = v;
        if (v > alpha) alpha = v;
        if (beta <= alpha) break;
      }
      return best;
    } else {
      int best = 999999;
      for (final t in turns) {
        if (_timedOut) break;
        final v = _minimax(_applyTurn(g.clone(), t), depth - 1, alpha, beta, true);
        if (v < best) best = v;
        if (v < beta) beta = v;
        if (beta <= alpha) break;
      }
      return best;
    }
  }

  static int _moveOrderScore(Game g, _AiTurn t) {
    final victim = g.boards[t.fl][t.tr][t.tc];
    var score = victim != null ? _pieceValue(victim.type) : 0;
    if (t.shiftToL != null) score += 12;
    return score;
  }

  static Game _applyTurn(Game g, _AiTurn t) {
    g.executeMove(t.fl, t.fr, t.fc, t.tr, t.tc);
    if (g.phase == GamePhase.shift) {
      if (t.shiftR != null && t.shiftToL != null) {
        g.executeShift(t.fl, t.shiftR!, t.shiftC!, t.shiftToL!);
      } else {
        g.skipShift();
      }
    }
    return g;
  }

  static List<_AiTurn> _generateTurns(Game g, {int cap = 40}) {
    final turns = <_AiTurn>[];
    for (int l = 0; l < g.boardCount; l++) {
      for (int fr = 0; fr < 8; fr++) {
        for (int fc = 0; fc < 8; fc++) {
          if (!g.isOwnPiece(l, fr, fc)) continue;
          final piece = g.boards[l][fr][fc]!;
          final moves = g.validMovesFrom(l, fr, fc);
          for (final mv in moves) {
            if (piece.type == PieceType.king) {
              turns.add(_AiTurn(fl: l, fr: fr, fc: fc, tr: mv.row, tc: mv.col));
              continue;
            }
            final g2 = g.clone();
            g2.executeMove(l, fr, fc, mv.row, mv.col);
            if (g2.phase == GamePhase.gameOver) {
              turns.add(_AiTurn(fl: l, fr: fr, fc: fc, tr: mv.row, tc: mv.col));
              continue;
            }
            // Skip shift (handled in _applyTurn via skipShift).
            turns.add(_AiTurn(fl: l, fr: fr, fc: fc, tr: mv.row, tc: mv.col));
            // One shift option per move keeps branching tractable on 3-board games.
            final shiftables = g2.shiftablePieces();
            if (shiftables.isNotEmpty) {
              final sp = shiftables.first;
              final targets = g2.shiftTargets(sp.level, sp.row, sp.col);
              if (targets.isNotEmpty) {
                turns.add(_AiTurn(
                  fl: l, fr: fr, fc: fc, tr: mv.row, tc: mv.col,
                  shiftR: sp.row, shiftC: sp.col, shiftToL: targets.first,
                ));
              }
            }
          }
        }
      }
    }
    if (turns.length > cap) {
      turns.sort((a, b) => _moveOrderScore(g, b).compareTo(_moveOrderScore(g, a)));
      return turns.sublist(0, cap);
    }
    return turns;
  }

  static int _evaluate(Game g) {
    int score = 0;
    for (int l = 0; l < g.boardCount; l++) {
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          final p = g.boards[l][r][c];
          if (p == null) continue;
          final v = _pieceValue(p.type);
          score += p.color == PieceColor.black ? v : -v;
        }
      }
    }
    return score;
  }

  static int _pieceValue(PieceType t) {
    switch (t) {
      case PieceType.pawn:   return 100;
      case PieceType.knight: return 320;
      case PieceType.bishop: return 330;
      case PieceType.rook:   return 500;
      case PieceType.queen:  return 900;
      case PieceType.king:   return 20000;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Online service  (Firestore)
// ═══════════════════════════════════════════════════════════════════════════════

class _OnlineService {
  static final _db  = FirebaseFirestore.instance;
  static const _col = 'schrodinger_chess_games';

  static String _makeCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static String _makeToken() {
    final rand = Random.secure();
    return List.generate(12, (_) =>
        rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<({String code, String token})> createGame({String? uid, int boardCount = 3}) async {
    final code  = _makeCode();
    final token = _makeToken();
    final g     = Game(boardCount: boardCount);
    await _db.collection(_col).doc(code).set({
      ...g.toMap(),
      'status':     'waiting',
      'whiteToken': token,
      'blackToken': '',
      'whiteUid':   uid ?? '',
      'blackUid':   '',
      'createdAt':  FieldValue.serverTimestamp(),
    });
    return (code: code, token: token);
  }

  // Returns the joiner's black token, or null if game not found / full.
  static Future<String?> joinGame(String code, {String? uid}) async {
    final ref = _db.collection(_col).doc(code);
    String? myToken;
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw 'not-found';
        final data = snap.data()!;
        if (data['status'] != 'waiting') throw 'not-waiting';
        if ((data['blackToken'] as String).isNotEmpty) throw 'full';
        myToken = _makeToken();
        tx.update(ref, {
          'blackToken': myToken,
          'blackUid':   uid ?? '',
          'status':     'active',
        });
      });
    } catch (_) {
      return null;
    }
    return myToken;
  }

  static Future<Map<String, dynamic>?> getGameData(String code) async {
    final snap = await _db.collection(_col).doc(code).get();
    return snap.exists ? snap.data() : null;
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchGame(String code) =>
      _db.collection(_col).doc(code).snapshots();

  static Future<void> pushState(String code, Game game) =>
      _db.collection(_col).doc(code).update(game.toMap());
}

// ═══════════════════════════════════════════════════════════════════════════════
// Auth service
// ═══════════════════════════════════════════════════════════════════════════════

class _AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;
  static GoogleSignIn? _google;

  static bool get _supportsAppleAuth =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  static GoogleSignIn _googleSignIn() =>
      _google ??= GoogleSignIn(
        scopes: const ['email', 'https://www.googleapis.com/auth/userinfo.profile'],
        clientId: !kIsWeb && Platform.isIOS
            ? DefaultFirebaseOptions.ios.iosClientId
            : null,
        serverClientId: !kIsWeb ? DefaultFirebaseOptions.ios.androidClientId : null,
      );

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authChanges => _auth.authStateChanges();

  static Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn().signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        await _googleSignIn().signOut();
        throw FirebaseAuthException(
          code: 'missing-id-token',
          message: 'Google Sign-In returned no ID token. Check Firebase iOS bundle ID '
              'matches the App Store id (${DefaultFirebaseOptions.ios.iosBundleId}).',
        );
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'null-user',
          message: 'Firebase sign-in returned no user after Google credential.',
        );
      }
      await _upsertProfile(user);
      return user;
    } on PlatformException catch (e) {
      throw FirebaseAuthException(
        code: e.code,
        message: e.message ?? 'Google Sign-In failed.',
      );
    }
  }

  static Future<User?> signInWithApple() async {
    if (!_supportsAppleAuth) return null;

    final rawNonce = _randomNonceString();
    final nonce = _sha256ofString(rawNonce);
    final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-apple-id-token',
        message: 'Sign in with Apple did not return an identity token.',
      );
    }
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
    );
    final result = await _auth.signInWithCredential(oauthCredential).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw FirebaseAuthException(
        code: 'timeout',
        message: 'Firebase sign-in timed out after Apple authorization.',
      ),
    );
    final user = result.user!;

    final builtName = [
      appleCredential.givenName,
      appleCredential.familyName,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    final fromApple = builtName.trim();
    if (fromApple.isNotEmpty &&
        (user.displayName == null || user.displayName!.trim().isEmpty)) {
      await user.updateDisplayName(fromApple);
      await user.reload();
    }

    // Do not block return on Firestore; profile sync can finish in the background.
    unawaited(_upsertProfileSafe(user));
    return user;
  }

  static Future<void> signOut() async {
    await _google?.signOut();
    await _auth.signOut();
  }

  static String _randomNonceString([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  static Future<void> _upsertProfile(User user) async {
    await _db.collection('users').doc(user.uid).set({
      'displayName': user.displayName ?? 'Player',
      'photoUrl':    user.photoURL    ?? '',
      'lastSeen':    FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _upsertProfileSafe(User user) async {
    try {
      await _upsertProfile(user).timeout(const Duration(seconds: 12));
    } catch (_) {
      // Sign-in already succeeded; Firestore can sync on next session.
    }
  }

  static Future<Map<String, dynamic>> getStats(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    final d = snap.data() ?? {};
    return {
      'displayName': d['displayName'] ?? 'Player',
      'photoUrl':    d['photoUrl']    ?? '',
      'wins':        d['wins']        ?? 0,
      'losses':      d['losses']      ?? 0,
      'draws':       d['draws']       ?? 0,
    };
  }

  static Future<void> recordResult(String uid, String result) async {
    final updates = <String, dynamic>{'gamesPlayed': FieldValue.increment(1)};
    if (result == 'win')  updates['wins']   = FieldValue.increment(1);
    if (result == 'loss') updates['losses'] = FieldValue.increment(1);
    if (result == 'draw') updates['draws']  = FieldValue.increment(1);
    await _db.collection('users').doc(uid).set(updates, SetOptions(merge: true));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Game screen
// ═══════════════════════════════════════════════════════════════════════════════

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Game   _game         = Game();
  Pos?   _selected;
  Pos?   _blinkPos;
  bool   _blinkVisible = true;
  Timer? _blinkTimer;
  int    _themeIndex   = 0;

  // Mode
  GameMode    _mode         = GameMode.twoPlayer;
  bool        _aiThinking   = false;

  // Online
  String?     _onlineCode;
  PieceColor? _myColor;
  bool        _waitingForOpponent = false;
  bool        _resultRecorded     = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _gameSub;

  // Auth
  User?       _currentUser;
  StreamSubscription<User?>? _authSub;

  // Purchases / ads
  bool        _adsRemoved  = false;
  bool        _adsSdkReady = false;
  /// null = still checking StoreKit; true = product loaded; false = hide Remove Ads UI.
  bool?       _removeAdsOfferAvailable;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  ChessTheme get _theme => kThemes[_themeIndex];
  bool get _vsAI     => _mode == GameMode.vsAI;
  bool get _isOnline => _mode == GameMode.online;

  List<String> get _labels => _game.boardCount == 2
      ? ['Board 1 · Bottom', 'Board 2 · Top']
      : ['Board 1 · Bottom', 'Board 2 · Middle', 'Board 3 · Top'];

  @override
  void initState() {
    super.initState();
    if (_firebaseAvailable) {
      _currentUser = _AuthService.currentUser;
      _authSub = _AuthService.authChanges.listen((user) {
        if (mounted) setState(() => _currentUser = user);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapAdsAndPurchases());
  }

  Future<void> _bootstrapAdsAndPurchases() async {
    if (!kIsWeb) {
      await _initializeMobileAdsIfNeeded();
    }
    if (!mounted) return;
    setState(() => _adsSdkReady = _mobileAdsInitialized || kIsWeb);
    await _initPurchases();
  }

  Future<void> _initPurchases() async {
    _adsRemoved = await _PurchaseService.loadAdsRemoved();
    if (!_adsRemoved && !kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      final product = await _PurchaseService.getProduct();
      _removeAdsOfferAvailable = product != null;
    } else {
      _removeAdsOfferAvailable = false;
    }
    if (mounted) setState(() {});
    _purchaseSub = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdate,
      onError: (Object error, _) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('StoreKit error: $error')),
        );
      },
    );
  }

  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        if (p.productID == _PurchaseService.productId) {
          await _PurchaseService.setAdsRemoved();
          if (mounted) setState(() => _adsRemoved = true);
        }
        await InAppPurchase.instance.completePurchase(p);
      } else if (p.status == PurchaseStatus.error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Purchase failed: '
                '${p.error?.message ?? p.error?.code ?? "Unknown error"}',
              ),
            ),
          );
        }
      } else if (p.status == PurchaseStatus.pending) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase pending approval…')),
          );
        }
      }
    }
  }

  Future<void> _purchaseRemoveAds() async {
    final product = await _PurchaseService.getProduct();
    if (!mounted) return;
    if (product == null) {
      final note = _PurchaseService.lastProductLookupNote ??
          'ensure the Remove Ads IAP is Ready to Submit / Approved in App Store Connect';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase unavailable: $note.')),
      );
      return;
    }
    try {
      final started = await _PurchaseService.buy(product);
      if (!mounted) return;
      if (!started) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_PurchaseService.lastPurchaseError ??
                'Purchase could not be started.'),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase error: ${e.message ?? e.code}')),
      );
    }
  }

  void _showRemoveAdsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Ads'),
        content: const Text(
          'Purchase once to permanently remove all ads.\n\n'
          'This supports the developer and keeps Schrödinger Chess free for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _PurchaseService.restore();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restoring purchases…')));
            },
            child: const Text('Restore'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () { Navigator.pop(context); _purchaseRemoveAds(); },
            child: const Text('Remove Ads — \$0.99'),
          ),
        ],
      ),
    );
  }

  // ── Blink ────────────────────────────────────────────────────────────────
  void _startBlink(Pos pos) {
    _blinkTimer?.cancel();
    int count = 0;
    setState(() { _blinkPos = pos; _blinkVisible = false; });
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 260), (t) {
      count++;
      if (count >= 12) {
        t.cancel();
        setState(() { _blinkPos = null; _blinkVisible = true; });
      } else {
        setState(() => _blinkVisible = !_blinkVisible);
      }
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _gameSub?.cancel();
    _authSub?.cancel();
    _purchaseSub?.cancel();
    super.dispose();
  }

  // ── AI ───────────────────────────────────────────────────────────────────
  void _maybeRunAI() {
    if (!_vsAI) return;
    if (_game.phase != GamePhase.move) return;
    if (_game.currentPlayer != PieceColor.black) return;
    if (_game.phase == GamePhase.gameOver) return;
    if (_aiThinking) return;
    setState(() => _aiThinking = true);
    _runAI();
  }

  Future<void> _runAI() async {
    final snapshot = _game.clone();
    // Let the "AI is thinking…" indicator paint before search runs.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    _AiTurn? turn;
    try {
      turn = await Future<_AiTurn?>(() => _ChessAI.bestTurn(snapshot)).timeout(
        const Duration(seconds: 4),
        onTimeout: () => _ChessAI.fallbackTurn(snapshot),
      );
    } catch (e, st) {
      assert(() {
        debugPrint('AI failed: $e\n$st');
        return true;
      }());
      turn = _ChessAI.fallbackTurn(snapshot);
    }
    if (!mounted) return;
    setState(() {
      _aiThinking = false;
      if (turn == null || _game.phase == GamePhase.gameOver) return;
      _game.executeMove(turn.fl, turn.fr, turn.fc, turn.tr, turn.tc);
      if (_game.phase == GamePhase.shift) {
        if (turn.shiftR != null && turn.shiftToL != null) {
          _game.executeShift(turn.fl, turn.shiftR!, turn.shiftC!, turn.shiftToL!);
          _startBlink(Pos(turn.shiftToL!, turn.shiftR!, turn.shiftC!));
        } else {
          _game.skipShift();
        }
      }
    });
  }

  // ── Profile ──────────────────────────────────────────────────────────────
  Future<void> _signInWithGoogleFromProfile() async {
    try {
      final user = await _AuthService.signInWithGoogle();
      if (!mounted) return;
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signed in as ${user.displayName ?? user.email ?? 'Player'}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    }
  }

  Future<void> _signInWithAppleFromProfile() async {
    try {
      final user = await _AuthService.signInWithApple();
      if (!mounted) return;
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signed in as ${user.displayName ?? user.email ?? 'Player'}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    }
  }

  void _openProfile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _theme.appBarBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _ProfileSheet(
        theme: _theme,
        user: _currentUser,
        firebaseAvailable: _firebaseAvailable,
        onSignInWithGoogle: _signInWithGoogleFromProfile,
        onSignInWithApple:
            (!kIsWeb && Platform.isIOS) ? _signInWithAppleFromProfile : null,
        onSignOut: () async {
          Navigator.pop(sheetContext);
          await _AuthService.signOut();
        },
      ),
    );
  }

  void _recordOnlineResult() {
    if (_resultRecorded) return;
    if (!_firebaseAvailable || _currentUser == null || !_isOnline) return;
    _resultRecorded = true;
    final w = _game.whiteKingsCaptured;
    final b = _game.blackKingsCaptured;
    final String result;
    if (w == b) {
      result = 'draw';
    } else if (_myColor == PieceColor.white) {
      result = w > b ? 'win' : 'loss';
    } else {
      result = b > w ? 'win' : 'loss';
    }
    _AuthService.recordResult(_currentUser!.uid, result);
  }

  // ── Online ───────────────────────────────────────────────────────────────
  void _maybeUploadState() {
    if (!_isOnline || _onlineCode == null) return;
    final turnEnded = _game.phase == GamePhase.gameOver ||
        (_game.phase == GamePhase.move && _game.currentPlayer != _myColor);
    if (turnEnded) {
      _OnlineService.pushState(_onlineCode!, _game);
    }
  }

  void _handleOnlineSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!mounted || !snap.exists) return;
    final data = snap.data()!;

    if (_waitingForOpponent) {
      if (data['status'] == 'active') {
        setState(() => _waitingForOpponent = false);
      }
      return;
    }

    // Apply only when Firestore reflects the opponent's completed turn
    // (phase==move and it's now my turn, or game is over).
    final phase  = data['phase'] as String;
    final player = data['currentPlayer'] as String;
    final mine   = _myColor == PieceColor.white ? 'white' : 'black';

    if (phase == 'gameOver' || (phase == 'move' && player == mine)) {
      setState(() {
        _game.applyMap(data);
        _selected = null;
      });
      if (phase == 'gameOver') _recordOnlineResult();
    }
  }

  Future<void> _createGame({int boardCount = 3}) async {
    try {
      final result = await _OnlineService.createGame(uid: _currentUser?.uid, boardCount: boardCount);
      if (!mounted) return;
      _blinkTimer?.cancel();
      _gameSub?.cancel();
      setState(() {
        _mode               = GameMode.online;

        _onlineCode         = result.code;
        _myColor            = PieceColor.white;
        _waitingForOpponent = true;
        _game               = Game(boardCount: boardCount);
        _selected           = null;
        _blinkPos           = null;
        _blinkVisible       = true;
        _aiThinking         = false;
      });
      _gameSub = _OnlineService.watchGame(result.code).listen(_handleOnlineSnapshot);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create game: $e')));
    }
  }

  Future<void> _joinGame(String code) async {
    final upper = code.toUpperCase().trim();
    final token = await _OnlineService.joinGame(upper, uid: _currentUser?.uid);
    if (!mounted) return;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game not found or already full.')));
      return;
    }
    final data = await _OnlineService.getGameData(upper);
    if (!mounted || data == null) return;

    _blinkTimer?.cancel();
    _gameSub?.cancel();
    final bc = (data['boardCount'] as int?) ?? 3;
    setState(() {
      _mode               = GameMode.online;
      _onlineCode         = upper;
      _myColor            = PieceColor.black;
      _waitingForOpponent = false;
      _game               = Game(boardCount: bc)..applyMap(data);
      _selected           = null;
      _blinkPos           = null;
      _blinkVisible       = true;
      _aiThinking         = false;
    });
    _gameSub = _OnlineService.watchGame(upper).listen(_handleOnlineSnapshot);
  }

  void _showJoinDialog() {
    final ctrl = TextEditingController();
    showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Join Online Game'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          style: const TextStyle(
              fontFamily: 'monospace', fontSize: 22, letterSpacing: 4),
          decoration: const InputDecoration(
            hintText: 'XXXXXX',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Join')),
        ],
      ),
    ).then((code) {
      if (code != null && code.trim().length == 6) { _joinGame(code); }
    });
  }

  // ── Move interaction ──────────────────────────────────────────────────────
  bool get _boardLocked {
    if (_game.phase == GamePhase.gameOver) return true;
    if (_aiThinking) return true;
    if (_waitingForOpponent) return true;
    if (_vsAI && _game.currentPlayer == PieceColor.black) return true;
    if (_isOnline && _myColor != null && _game.currentPlayer != _myColor) return true;
    return false;
  }

  void _tap(int level, int row, int col) {
    if (_boardLocked) return;
    if (_game.phase == GamePhase.shift) { _doShiftTap(level, row, col); return; }

    final tapped = Pos(level, row, col);
    if (_selected == null) {
      if (_game.isOwnPiece(level, row, col)) setState(() => _selected = tapped);
      return;
    }
    final sel = _selected!;
    if (sel == tapped) { setState(() => _selected = null); return; }
    if (_game.isOwnPiece(level, row, col)) { setState(() => _selected = tapped); return; }
    if (level == sel.level) {
      final valid = _game.validMovesFrom(sel.level, sel.row, sel.col);
      setState(() {
        if (valid.contains(tapped)) { _game.executeMove(sel.level, sel.row, sel.col, row, col); }
        _selected = null;
      });
      _maybeRunAI();
      _maybeUploadState();
    } else {
      setState(() => _selected = null);
    }
  }

  void _doShiftTap(int l, int r, int c) {
    final p = _game.pieceAt(l, r, c);
    if (p == null || p.color != _game.currentPlayer || p.type == PieceType.king) return;
    final targets = _game.shiftTargets(l, r, c);
    if (targets.isEmpty) return;

    if (targets.length == 1) {
      final tl = targets.first;
      setState(() => _game.executeShift(l, r, c, tl));
      _startBlink(Pos(tl, r, c));
      _maybeRunAI();
      _maybeUploadState();
    } else {
      showDialog<int>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Shift direction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: targets.map((t) => ListTile(
              leading: Icon(
                  _game._shiftUp(l) == t ? Icons.arrow_upward : Icons.arrow_downward),
              title: Text('${_game._shiftUp(l) == t ? "Up" : "Down"} → ${_labels[t]}'),
              onTap: () => Navigator.pop(context, t),
            )).toList(),
          ),
          actions: [TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'))],
        ),
      ).then((t) {
        if (t != null) {
          setState(() => _game.executeShift(l, r, c, t));
          _startBlink(Pos(t, r, c));
          _maybeRunAI();
          _maybeUploadState();
        }
      });
    }
  }

  // ── New game ──────────────────────────────────────────────────────────────
  void _newGame() {
    GameMode mode = _mode == GameMode.online ? GameMode.twoPlayer : _mode;
    int boardCount = _game.boardCount;
    showDialog<_GameConfig>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New game'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Boards', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('2 Boards'), icon: Icon(Icons.layers)),
                ButtonSegment(value: 3, label: Text('3 Boards'), icon: Icon(Icons.stacked_bar_chart)),
              ],
              selected: {boardCount},
              onSelectionChanged: (s) => setLocal(() => boardCount = s.first),
            ),
            const SizedBox(height: 16),
            const Text('Opponent', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 14),
            SegmentedButton<GameMode>(
              segments: [
                const ButtonSegment(
                  value: GameMode.twoPlayer,
                  label: Text('2 Players'),
                  icon: Icon(Icons.people),
                ),
                const ButtonSegment(
                  value: GameMode.vsAI,
                  label: Text('vs AI'),
                  icon: Icon(Icons.computer),
                ),
                ButtonSegment(
                  value: GameMode.online,
                  label: const Text('Online'),
                  icon: const Icon(Icons.wifi),
                  enabled: _firebaseAvailable,
                ),
              ],
              selected: {mode},
              onSelectionChanged: (s) => setLocal(() => mode = s.first),
            ),
            if (mode == GameMode.vsAI) ...[
              const SizedBox(height: 10),
              const Text('You play White. AI plays Black.',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ] else if (mode == GameMode.online) ...[
              const SizedBox(height: 12),
              const Text(
                'Create a game and share the code with your friend, or enter their code to join.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Create Game  →  get a code'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _createGame(boardCount: boardCount);
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Join Game  →  enter a code'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showJoinDialog();
                },
              ),
            ] else if (!_firebaseAvailable) ...[
              const SizedBox(height: 8),
              const Text('Online requires Firebase setup.',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            if (mode != GameMode.online)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, (mode: mode, boardCount: boardCount)),
                child: const Text('Start'),
              ),
          ],
        ),
      ),
    ).then((result) {
      if (result != null) {
        _blinkTimer?.cancel();
        _gameSub?.cancel();
        setState(() {
          _mode               = result.mode;

          _onlineCode         = null;
          _myColor            = null;
          _waitingForOpponent = false;
          _resultRecorded     = false;
          _aiThinking         = false;
          _game               = Game(boardCount: result.boardCount);
          _selected           = null;
          _blinkPos           = null;
          _blinkVisible       = true;
        });
      }
    });
  }

  // ── Rules ─────────────────────────────────────────────────────────────────
  void _openRules() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _RulesScreen(theme: _theme),
    ));
  }

  // ── Theme picker ──────────────────────────────────────────────────────────
  void _openThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _theme.appBarBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Choose theme',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: kThemes.length,
            itemBuilder: (_, i) {
              final t = kThemes[i];
              final selected = i == _themeIndex;
              return GestureDetector(
                onTap: () {
                  setState(() => _themeIndex = i);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? Colors.white : Colors.white24,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  child: Column(children: [
                    Expanded(child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10)),
                      child: GridView.count(
                        crossAxisCount: 4,
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        children: List.generate(16, (j) {
                          final row = j ~/ 4, col = j % 4;
                          return Container(
                              color: (row + col) % 2 == 0 ? t.lightSq : t.darkSq);
                        }),
                      ),
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: t.appBarBg,
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(10)),
                      ),
                      child: Column(children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 14)),
                        Text(t.name,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 9,
                                fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final validMoves = _selected != null
        ? _game.validMovesFrom(_selected!.level, _selected!.row, _selected!.col).toSet()
        : const <Pos>{};
    final shiftable = _game.phase == GamePhase.shift
        ? _game.shiftablePieces().toSet()
        : const <Pos>{};

    // Mode badge text
    String? badge;
    if (_vsAI)     badge = 'AI';
    if (_isOnline) badge = 'Online';

    return Scaffold(
      backgroundColor: t.appBg,
      appBar: AppBar(
        backgroundColor: t.appBarBg,
        foregroundColor: Colors.white,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Flexible(
            child: Text('Schrödinger Chess',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(badge,
                  style: const TextStyle(fontSize: 10, color: Colors.white70)),
            ),
          ],
        ]),
        actions: [
          if (!_adsRemoved && (_removeAdsOfferAvailable ?? false))
            IconButton(
              icon: const Icon(Icons.block, size: 20),
              tooltip: 'Remove Ads',
              onPressed: _showRemoveAdsDialog,
            ),
          if (_firebaseAvailable)
            IconButton(
              tooltip: _currentUser != null ? _currentUser!.displayName ?? 'Profile' : 'Sign In',
              onPressed: _openProfile,
              icon: _currentUser?.photoURL != null
                  ? CircleAvatar(
                      radius: 13,
                      backgroundImage: NetworkImage(_currentUser!.photoURL!),
                    )
                  : const Icon(Icons.account_circle_outlined),
            ),
          IconButton(
              icon: const Icon(Icons.menu_book_outlined),
              tooltip: 'Rules',
              onPressed: _openRules),
          IconButton(
              icon: const Icon(Icons.palette_outlined),
              tooltip: 'Theme',
              onPressed: _openThemePicker),
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'New game',
              onPressed: _newGame),
        ],
      ),
      body: Column(children: [
        if (!_adsRemoved && _adsSdkReady) const _BannerAdWidget(),
        _StatusBar(
          game:               _game,
          theme:              t,
          aiThinking:         _aiThinking,
          isOnline:           _isOnline,
          myColor:            _myColor,
          waitingForOpponent: _waitingForOpponent,
          onlineCode:         _onlineCode,
          onSkip: () {
            setState(() => _game.skipShift());
            _maybeRunAI();
            _maybeUploadState();
          },
        ),
        if (_waitingForOpponent && _onlineCode != null)
          Expanded(child: Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(
                width: 48, height: 48,
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white54),
              ),
              const SizedBox(height: 28),
              const Text('Waiting for opponent…',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 28),
              const Text('Share this code with your friend:',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                decoration: BoxDecoration(
                  color: t.appBarBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(_onlineCode!,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 10)),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy Code'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _onlineCode!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied to clipboard!')));
                },
              ),
            ]),
          ))),
        if (!_waitingForOpponent) Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: [
              for (int lvl = _game.boardCount - 1; lvl >= 0; lvl--)
                _BoardSection(
                  level: lvl, label: _labels[lvl], game: _game,
                  theme: t, selected: _selected,
                  validMoves: validMoves, shiftable: shiftable,
                  onTap: _tap,
                  blinkPos: _blinkPos, blinkVisible: _blinkVisible,
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// In-app purchase  (Remove Ads — $0.99 non-consumable)
// ═══════════════════════════════════════════════════════════════════════════════

class _PurchaseService {
  static const productId = 'com.pryroinc.schrodingerchess.removead';
  static const _prefKey  = 'ads_removed';
  static final  _iap     = InAppPurchase.instance;

  /// Explanation for debugging when `getProduct` returns null.
  static String? lastProductLookupNote;
  /// Set when `buy` returns false or throws internally.
  static String? lastPurchaseError;

  static Future<bool> loadAdsRemoved() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  static Future<void> setAdsRemoved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  static Future<ProductDetails?> getProduct() async {
    lastProductLookupNote = null;
    if (!await _iap.isAvailable()) {
      lastProductLookupNote = 'in-app purchases are not available on this device';
      return null;
    }
    final response = await _iap.queryProductDetails({productId});
    if (response.productDetails.isNotEmpty) {
      return response.productDetails.first;
    }
    if (response.notFoundIDs.isNotEmpty) {
      lastProductLookupNote =
          'products not loaded from App Store (${response.notFoundIDs.join(', ')})';
      return null;
    }
    if (response.error != null) {
      lastProductLookupNote = response.error!.message;
      return null;
    }
    lastProductLookupNote = 'product query returned empty with no diagnostics';
    return null;
  }

  static Future<bool> buy(ProductDetails product) async {
    lastPurchaseError = null;
    try {
      return await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } on PlatformException catch (e) {
      lastPurchaseError = e.message ?? e.code;
      return false;
    }
  }

  static Future<void> restore() => _iap.restorePurchases();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Banner ad
// ═══════════════════════════════════════════════════════════════════════════════

class _BannerAdWidget extends StatefulWidget {
  const _BannerAdWidget();
  @override
  State<_BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<_BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ad == null) _loadAd();
  }

  Future<void> _loadAd() async {
    if (!_mobileAdsInitialized && !kIsWeb) return;
    final width = MediaQuery.of(context).size.width.truncate();
    final size  = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;
    final ad = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) { if (mounted) setState(() => _loaded = true); },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
    await ad.load();
    if (!mounted) { ad.dispose(); return; }
    setState(() => _ad = ad);
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return SizedBox(
      width:  _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child:  AdWidget(ad: _ad!),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Profile sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _ProfileSheet extends StatefulWidget {
  final ChessTheme theme;
  final User? user;
  final bool firebaseAvailable;
  final Future<void> Function() onSignInWithGoogle;
  final Future<void> Function()? onSignInWithApple;
  final VoidCallback onSignOut;
  const _ProfileSheet({
    required this.theme,
    required this.user,
    required this.firebaseAvailable,
    required this.onSignInWithGoogle,
    this.onSignInWithApple,
    required this.onSignOut,
  });
  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  Map<String, dynamic>? _stats;
  bool _loading = false;
  bool _appleSignInAvailable = false;
  bool _signInInProgress = false;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _loadStats();
    } else {
      if (widget.onSignInWithApple != null) {
        SignInWithApple.isAvailable().then((available) {
          if (mounted) setState(() => _appleSignInAvailable = available);
        });
      }
      // Close sheet as soon as auth succeeds (backup if Apple UI lingers on iPad).
      _authSub = _AuthService.authChanges.listen((user) {
        if (user != null && mounted && widget.user == null) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Dismiss profile sheet before OAuth so iPad does not stack Apple UI on a bottom sheet.
  Future<void> _beginOAuthSignIn(Future<void> Function() signIn) async {
    if (_signInInProgress) return;
    setState(() => _signInInProgress = true);
    final sheetNavigator = Navigator.of(context);
    sheetNavigator.pop();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await signIn();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final s = await _AuthService.getStats(widget.user!.uid);
    if (mounted) setState(() { _stats = s; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final t    = widget.theme;
    final user = widget.user;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),

        if (user == null) ...[
          // ── Guest ──
          const Icon(Icons.account_circle, size: 56, color: Colors.white38),
          const SizedBox(height: 12),
          const Text('Playing as Guest',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Sign in to track your wins & losses across sessions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 24),
          if (widget.firebaseAvailable) ...[
            if (widget.onSignInWithApple != null && _appleSignInAvailable) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: SignInWithAppleButton(
                  onPressed: _signInInProgress
                      ? () {}
                      : () => _beginOAuthSignIn(widget.onSignInWithApple!),
                  style: SignInWithAppleButtonStyle.black,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Text('G', style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                label: const Text('Sign in with Google',
                    style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _signInInProgress
                    ? null
                    : () => _beginOAuthSignIn(widget.onSignInWithGoogle),
              ),
            ),
          ],
          if (!widget.firebaseAvailable)
            const Text('Firebase not configured — online features unavailable.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12)),
        ] else ...[
          // ── Signed in ──
          CircleAvatar(
            radius: 32,
            backgroundImage: user.photoURL != null
                ? NetworkImage(user.photoURL!) : null,
            backgroundColor: t.accents[1].withAlpha(80),
            child: user.photoURL == null
                ? Text((user.displayName ?? 'P')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 26, color: Colors.white))
                : null,
          ),
          const SizedBox(height: 12),
          Text(user.displayName ?? 'Player',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 2),
          Text(user.email ?? '',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 24),

          // Stats row
          if (_loading)
            const CircularProgressIndicator(strokeWidth: 2)
          else
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _StatBox(label: 'Wins',   value: _stats?['wins']   ?? 0, color: Colors.greenAccent),
              _StatBox(label: 'Losses', value: _stats?['losses'] ?? 0, color: Colors.redAccent),
              _StatBox(label: 'Draws',  value: _stats?['draws']  ?? 0, color: Colors.white38),
            ]),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, size: 18, color: Colors.white70),
              label: const Text('Sign out', style: TextStyle(color: Colors.white70)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: widget.onSignOut,
            ),
          ),
        ],
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final int    value;
  final Color  color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('$value',
          style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Rules screen
// ═══════════════════════════════════════════════════════════════════════════════

class _RulesScreen extends StatelessWidget {
  final ChessTheme theme;
  const _RulesScreen({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Scaffold(
      backgroundColor: t.appBg,
      appBar: AppBar(
        backgroundColor: t.appBarBg,
        foregroundColor: Colors.white,
        title: const Text('How to Play',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          _RuleSection(theme: t, icon: '♟', title: 'Overview', body:
            'Schrödinger Chess is played on 2 or 3 stacked 8×8 boards (choose when starting a new game). '
            'Each board starts with a full standard chess setup for both sides. '
            'The goal is to capture all of your opponent\'s kings before they capture yours.'),

          _RuleSection(theme: t, icon: '🔢', title: 'Turn Structure',
            body: 'Every turn has two phases:\n\n'
                  '1 · MOVE — Choose one board and make any legal chess move on it. '
                  'Pieces never move between boards on their own.\n\n'
                  '2 · SHIFT — After moving, you may teleport one of your non-king pieces '
                  'from that same board up or down one level. '
                  'The destination square must be empty. You may skip the shift.'),

          _RuleSection(theme: t, icon: '🔄', title: 'Circular Shifting',
            body: 'Shifting is circular across all three boards:\n\n'
                  '• Shifting UP from Board 3 (top) wraps to Board 1 (bottom)\n'
                  '• Shifting DOWN from Board 1 (bottom) wraps to Board 3 (top)\n\n'
                  'This means every piece always has two potential shift directions.'),

          _RuleSection(theme: t, icon: '👑', title: 'Kings',
            body: 'Kings follow standard chess movement within their board. '
                  'Kings CANNOT be shifted between boards — ever.\n\n'
                  'When a king is captured (an opponent\'s piece moves onto its square), '
                  'that board continues without that king. '
                  'Pieces on a kingless board can still move and shift freely.'),

          _RuleSection(theme: t, icon: '🏆', title: 'Winning',
            body: 'Each king capture scores 1 point (max 3 per player).\n\n'
                  'The game ends immediately when one player loses ALL 3 kings. '
                  'The winner is the player with more king captures at that moment '
                  '(always the player who just took the last king).\n\n'
                  'If both players somehow have the same score, the game is a draw.'),

          _RuleSection(theme: t, icon: '🎮', title: 'Game Modes',
            body: '• 2 Players — pass the device between turns\n'
                  '• vs AI — you play White, the AI plays Black (tap New Game to choose)\n'
                  '• Online — play with a friend over the internet via a 6-letter room code '
                  '(requires Firebase setup — see developer notes)'),

          _RuleSection(theme: t, icon: '💡', title: 'Strategy Tips',
            body: '• Shifts are powerful — use them to move pieces to boards where they\'re needed\n'
                  '• A piece shifted to a new board can attack immediately on your next turn\n'
                  '• Losing a king on one board is not fatal — you can still score on the others\n'
                  '• Control the shift to threaten kings on multiple boards at once'),

          _RuleSection(theme: t, icon: '⚠️', title: 'Current Limitations',
            body: 'This version does not implement:\n'
                  '• Check or checkmate detection (kings are captured directly)\n'
                  '• En passant\n'
                  '• Castling\n'
                  '• Pawn promotion\n'
                  '• Draw conditions (stalemate, 50-move rule)'),
        ],
      ),
    );
  }
}

class _RuleSection extends StatelessWidget {
  final ChessTheme theme;
  final String icon, title, body;
  const _RuleSection({required this.theme, required this.icon,
      required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final accent = theme.accents[1];
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(
              color: accent, fontWeight: FontWeight.bold,
              fontSize: 16, letterSpacing: 0.4)),
        ]),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            border: Border(left: BorderSide(color: accent.withAlpha(120), width: 3)),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
          ),
          child: Text(body,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13.5, height: 1.6)),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Status bar
// ═══════════════════════════════════════════════════════════════════════════════

class _StatusBar extends StatelessWidget {
  final Game       game;
  final ChessTheme theme;
  final bool       aiThinking;
  final bool       isOnline;
  final PieceColor? myColor;
  final bool       waitingForOpponent;
  final String?    onlineCode;
  final VoidCallback onSkip;

  const _StatusBar({
    required this.game,
    required this.theme,
    required this.aiThinking,
    required this.isOnline,
    required this.myColor,
    required this.waitingForOpponent,
    required this.onlineCode,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final t       = theme;
    final isWhite = game.currentPlayer == PieceColor.white;
    final isShift = game.phase == GamePhase.shift;
    final isOver  = game.phase == GamePhase.gameOver;

    final bg = isOver  ? t.statusOverBg
             : isShift ? t.statusShiftBg
             : isWhite ? t.statusWhiteBg
                       : t.statusBlackBg;

    // Waiting for opponent to join
    if (waitingForOpponent && onlineCode != null) {
      return Container(
        decoration: BoxDecoration(
          color: t.statusShiftBg,
          border: const Border(bottom: BorderSide(color: Colors.white12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(children: [
          const SizedBox(
            width: 13, height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
          ),
          const SizedBox(width: 10),
          Expanded(child: RichText(text: TextSpan(
            style: const TextStyle(fontSize: 13, color: Colors.white70),
            children: [
              const TextSpan(text: 'Share code: '),
              TextSpan(text: onlineCode,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 3)),
            ],
          ))),
          IconButton(
            icon: const Icon(Icons.copy, size: 18, color: Colors.white70),
            tooltip: 'Copy code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: onlineCode!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied to clipboard')));
            },
          ),
        ]),
      );
    }

    // Online: opponent's turn → show waiting indicator
    final opponentTurn = isOnline && myColor != null && !isOver &&
        game.currentPlayer != myColor && !isShift;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: bg,
        border: const Border(bottom: BorderSide(color: Colors.white12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(children: [
        if (aiThinking) ...[
          const SizedBox(
            width: 13, height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('AI is thinking…',
              style: TextStyle(
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                  fontSize: 13))),
        ] else if (opponentTurn) ...[
          const SizedBox(
            width: 13, height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Waiting for ${game.currentPlayer == PieceColor.white ? "White" : "Black"}…',
            style: const TextStyle(
                color: Colors.white60, fontStyle: FontStyle.italic, fontSize: 13))),
        ] else ...[
          if (!isOver)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 13, height: 13,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isWhite ? Colors.white : Colors.black,
                border: Border.all(color: Colors.white38, width: 1.5),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: isWhite
                      ? Colors.white.withAlpha(60)
                      : Colors.black.withAlpha(80),
                  blurRadius: 6,
                )],
              ),
            ),
          Expanded(child: Text(game.statusText,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13))),
          if (isShift)
            TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white12,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Skip'),
            ),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Board section
// ═══════════════════════════════════════════════════════════════════════════════

class _BoardSection extends StatelessWidget {
  final int level;
  final String label;
  final Game game;
  final ChessTheme theme;
  final Pos? selected;
  final Set<Pos> validMoves;
  final Set<Pos> shiftable;
  final void Function(int, int, int) onTap;
  final Pos? blinkPos;
  final bool blinkVisible;

  const _BoardSection({
    required this.level, required this.label, required this.game,
    required this.theme, required this.selected,
    required this.validMoves, required this.shiftable, required this.onTap,
    required this.blinkPos, required this.blinkVisible,
  });

  @override
  Widget build(BuildContext context) {
    final t      = theme;
    final accent = t.accents[level];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(children: [
            Container(
              width: 3, height: 14,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                  color: accent, borderRadius: BorderRadius.circular(2)),
            ),
            Text(label, style: TextStyle(
                color: accent, fontWeight: FontWeight.bold,
                fontSize: 12, letterSpacing: 0.6)),
          ]),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: accent.withAlpha(110), width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LayoutBuilder(builder: (_, constraints) {
              final size = constraints.maxWidth;
              final sq   = size / 8;
              return SizedBox(
                width: size, height: size,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8),
                  itemCount: 64,
                  itemBuilder: (_, i) {
                    final row = i ~/ 8, col = i % 8;
                    final pos        = Pos(level, row, col);
                    final piece      = game.pieceAt(level, row, col);
                    final light      = (row + col) % 2 == 0;
                    final isSel      = selected == pos;
                    final isValid    = validMoves.contains(pos);
                    final isCapture  = isValid && piece != null;
                    final isShiftSq  = shiftable.contains(pos);
                    final isBlinking = blinkPos == pos && !blinkVisible;

                    final bg = isSel     ? t.selectedSq
                             : isCapture ? t.captureSq
                             : isShiftSq ? (light ? t.shiftLightSq : t.shiftDarkSq)
                             : light     ? t.lightSq
                                         : t.darkSq;

                    final pieceColor = piece?.color == PieceColor.white
                        ? Colors.white
                        : const Color(0xFF080810);
                    final shadowColor = piece?.color == PieceColor.white
                        ? Colors.black
                        : Colors.white;

                    return GestureDetector(
                      onTap: () => onTap(level, row, col),
                      child: Container(
                        color: bg,
                        child: Stack(alignment: Alignment.center, children: [
                          if (isValid && piece == null)
                            Container(
                              width: sq * 0.32, height: sq * 0.32,
                              decoration: BoxDecoration(
                                color: t.validDot.withAlpha(180),
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (piece != null && !isBlinking)
                            Text(piece.symbol, style: TextStyle(
                              fontSize: sq * 0.72, height: 1.0,
                              color: pieceColor,
                              shadows: [Shadow(
                                color: shadowColor,
                                blurRadius: 3,
                                offset: const Offset(0.7, 0.7),
                              )],
                            )),
                          if (isShiftSq && piece != null)
                            Positioned(
                              bottom: 1, right: 1,
                              child: Icon(Icons.swap_vert,
                                  size: sq * 0.30, color: t.shiftIcon),
                            ),
                        ]),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
      ]),
    );
  }
}
