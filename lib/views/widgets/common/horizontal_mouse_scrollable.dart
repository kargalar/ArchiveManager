import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class HorizontalMouseScrollable extends StatefulWidget {
  final Widget child;
  const HorizontalMouseScrollable({super.key, required this.child});

  @override
  State<HorizontalMouseScrollable> createState() => _HorizontalMouseScrollableState();
}

class _HorizontalMouseScrollableState extends State<HorizontalMouseScrollable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final offset = _scrollController.offset + event.scrollDelta.dy;
          _scrollController.jumpTo(
            offset.clamp(0.0, _scrollController.position.maxScrollExtent),
          );
        }
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: widget.child,
      ),
    );
  }
}
