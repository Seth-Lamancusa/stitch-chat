import '../../data/models/message.dart';
import '../../data/repositories/message_repository.dart';
import '../core/adaptive_marker.dart';

/// Everything a single row in a column's message list needs to render its
/// navigators. Both navigators attach to a message based on whether it has
/// a *previous* row above it: [outgoing]/[outgoingCurrentIndex]/
/// [outgoingAnchorId] are null/-1/null and [incoming]/[incomingCurrentIndex]
/// are null/-1 when this is the first message currently displayed in the
/// branch — there's no row above it, so neither the pool it occupies a slot
/// in ([OutgoingNavigator], cycling its parent's other children) nor its own
/// incoming pool ([IncomingNavigator], cycling its own other parents) has
/// anywhere to attach; that boundary is the top [AdaptiveMarker]'s job
/// instead.
class MessageRowData {
  final Message message;
  final OutgoingEdges? outgoing;
  final int outgoingCurrentIndex;

  /// Id of the message whose outgoing pool [outgoing] is (i.e. the previous
  /// row, the parent this message currently occupies a slot under) — needed
  /// because [outgoing] renders beside *this* message but the pool itself
  /// belongs to the parent, so navigation calls must target that id, not
  /// [message]'s.
  final String? outgoingAnchorId;
  final IncomingEdges? incoming;
  final int incomingCurrentIndex;

  const MessageRowData({
    required this.message,
    required this.outgoing,
    required this.outgoingCurrentIndex,
    required this.outgoingAnchorId,
    required this.incoming,
    required this.incomingCurrentIndex,
  });
}

/// One column's full render state: its currently-displayed linear branch
/// plus derived marker state at each end. Mutated in place by
/// `ColumnsViewModel` and surfaced via `ChangeNotifier.notifyListeners`.
class ColumnUiState {
  final String id;
  double? width;
  bool isActive;
  List<MessageRowData> rows;

  MarkerVisualState topMarker;
  int topStitchCount;
  bool topLoading;
  String? topError;

  MarkerVisualState bottomMarker;
  int bottomStitchCount;
  bool bottomLoading;
  String? bottomError;

  ColumnUiState({
    required this.id,
    this.width,
    this.isActive = false,
    this.rows = const [],
    this.topMarker = MarkerVisualState.end,
    this.topStitchCount = 0,
    this.topLoading = false,
    this.topError,
    this.bottomMarker = MarkerVisualState.end,
    this.bottomStitchCount = 0,
    this.bottomLoading = false,
    this.bottomError,
  });
}
