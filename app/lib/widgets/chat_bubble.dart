import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/colors.dart';
import 'mascot.dart';

/// One chat line: my messages on the right in cherry red, theirs on the left in white,
/// and Cherry's in soft pink beside the viewer's own cherry.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, required this.mine, this.cherryPose});

  final ChatMessage message;
  final bool mine;
  final MascotPose? cherryPose;

  @override
  Widget build(BuildContext context) {
    final cherry = message.fromCherry;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cherry
            ? BakeColors.softPink
            : mine
                ? BakeColors.cherryRed
                : Colors.white,
        border: mine ? null : Border.all(color: cherry ? const Color(0xFFF7D3D9) : BakeColors.line),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 4),
          bottomRight: Radius.circular(mine ? 4 : 18),
        ),
      ),
      child: Text(
        message.text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: mine ? Colors.white : BakeColors.charcoal,
              fontWeight: FontWeight.w600,
            ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (cherry) ...[
            Mascot(cherryPose ?? MascotPose.boyHello, size: 40, bob: false),
            const SizedBox(width: 6),
          ],
          bubble,
        ],
      ),
    );
  }
}
