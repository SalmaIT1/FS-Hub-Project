import 'package:flutter/material.dart';

/// Shows upload progress for attachments
/// 
/// States:
/// - Pending: waiting to upload
/// - Uploading: progress bar 0-100%
/// - Completed: checkmark
/// - Failed: delete/retry option
class UploadProgressIndicator extends StatelessWidget {
  final String filename;
  final double progress; // 0-1
  final int fileSize; // bytes
  final bool isComplete;
  final bool isFailed;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const UploadProgressIndicator({
    Key? key,
    required this.filename,
    this.progress = 0.0,
    this.fileSize = 0,
    this.isComplete = false,
    this.isFailed = false,
    this.onRetry,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          // Icon
          if (isFailed)
            Icon(Icons.error, color: Colors.red)
          else if (isComplete)
            Icon(Icons.check_circle, color: Colors.green)
          else
            Icon(Icons.attachment),
          SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (!isComplete && !isFailed)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                      ),
                    ),
                  )
                else if (isFailed)
                  Text(
                    'Upload failed',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
              ],
            ),
          ),
          SizedBox(width: 12),
          // Action button
          if (isFailed && onRetry != null)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: onRetry,
              iconSize: 20,
            )
          else if (!isComplete && !isFailed && onCancel != null)
            IconButton(
              icon: Icon(Icons.close),
              onPressed: onCancel,
              iconSize: 20,
            ),
        ],
      ),
    );
  }
}
