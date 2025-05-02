import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_helper.dart';
import 'call_details.dart';

class RecentActivityPage extends StatefulWidget {
  @override
  _RecentActivityPageState createState() => _RecentActivityPageState();
}

class _RecentActivityPageState extends State<RecentActivityPage> {
  List<CallDetails> _allCallHistory = [];
  bool _isLoading = true;
  bool _isDeleting = false;

  // Define our color scheme constants
  static const Color primaryGreen = Color(0xff235543);
  static const Color lightGreen = Color(0xff75e4bb);
  static const Color backgroundGreen = Color(0xfff0f8f5);

  @override
  void initState() {
    super.initState();
    _loadAllCallHistory();
  }

  Future<void> _loadAllCallHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the call history without refreshing
      List<CallDetails> history = await ApiHelper.getCallHistory();

      setState(() {
        _allCallHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading call history: $e');
      _showCustomSnackBar("Failed to load call history. Please try again.",
          isError: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshCallHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Refresh call details
      await ApiHelper.refreshCallHistory();

      // Get updated call history
      List<CallDetails> history = await ApiHelper.getCallHistory();

      setState(() {
        _allCallHistory = history;
        _isLoading = false;
      });

      _showCustomSnackBar("Activity refreshed successfully");
    } catch (e) {
      print('Error refreshing call history: $e');
      _showCustomSnackBar("Failed to refresh call details. Please try again.",
          isError: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCallItem(String callId) async {
    setState(() {
      _isDeleting = true;
    });

    try {
      bool success = await ApiHelper.deleteCallFromHistory(callId);

      if (success) {
        await _loadAllCallHistory();
        _showCustomSnackBar("Activity deleted successfully");
      } else {
        _showCustomSnackBar("Failed to delete activity", isError: true);
      }
    } catch (e) {
      print('Error deleting call: $e');
      _showCustomSnackBar("An error occurred while deleting", isError: true);
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  Future<void> _showDeleteConfirmationDialog(String callId) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Delete Activity",
            style: TextStyle(
              color: primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            "Are you sure you want to delete this activity? This action cannot be undone.",
            style: TextStyle(
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                "CANCEL",
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteCallItem(callId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "DELETE",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showClearAllConfirmationDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Clear All Activity",
            style: TextStyle(
              color: primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            "Are you sure you want to clear all your activity history? This action cannot be undone.",
            style: TextStyle(
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                "CANCEL",
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearAllActivity();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "CLEAR ALL",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearAllActivity() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      bool success = await ApiHelper.clearAllCallHistory();

      if (success) {
        setState(() {
          _allCallHistory = [];
        });

        _showCustomSnackBar("All activity cleared successfully");
      } else {
        _showCustomSnackBar("Failed to clear activity history", isError: true);
      }
    } catch (e) {
      print('Error clearing activity: $e');
      _showCustomSnackBar("An error occurred while clearing activity",
          isError: true);
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: isError ? Colors.redAccent : primaryGreen,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  String _formatDateTime(String isoString) {
    try {
      // Handle ISO 8601 format with timezone information
      DateTime dateTime;

      try {
        // First try standard parsing
        dateTime = DateTime.parse(isoString);
      } catch (e) {
        // If standard parsing fails, try manually handling the format
        // For timestamps like: 2025-04-13T09:23:47.948+00:00

        // Remove the timezone part if it's causing issues
        String simplifiedString = isoString;
        if (isoString.contains('+')) {
          simplifiedString = isoString.substring(0, isoString.indexOf('+'));
        } else if (isoString.contains('Z')) {
          simplifiedString = isoString.substring(0, isoString.indexOf('Z'));
        }

        // Try parsing again
        dateTime = DateTime.parse(simplifiedString);
      }

      // Convert to local time for display
      dateTime = dateTime.toLocal();

      // Format based on how recent the date is
      DateTime now = DateTime.now();
      DateTime yesterday = now.subtract(const Duration(days: 1));

      if (dateTime.year == now.year &&
          dateTime.month == now.month &&
          dateTime.day == now.day) {
        return "Today, ${DateFormat('hh:mm a').format(dateTime)}";
      } else if (dateTime.year == yesterday.year &&
          dateTime.month == yesterday.month &&
          dateTime.day == yesterday.day) {
        return "Yesterday, ${DateFormat('hh:mm a').format(dateTime)}";
      } else {
        return DateFormat('MMM dd, hh:mm a').format(dateTime);
      }
    } catch (e) {
      // Log the error for debugging
      print('Error parsing date: $e for input: $isoString');
      return "Unknown date";
    }
  }

  // Function to truncate the summary to a certain length
  String _truncateSummary(String summary, int maxLength) {
    if (summary.length <= maxLength) {
      return summary;
    }
    return "${summary.substring(0, maxLength)}...";
  }

  Widget _buildCallHistoryItem(CallDetails call) {
    String displayPhoneNumber =
        call.phoneNumber.replaceAll(RegExp(r'\+91'), '');
    String title;
    IconData iconData;

    // Determine the appropriate icon and title based on call status
    if (call.status == 'completed') {
      iconData = Icons.phone;
      title = "Call with LawSaathi";
      if (call.summary.isNotEmpty && call.summary != 'No summary available') {
        title += " - ${_truncateSummary(call.summary, 30)}";
      } else {
        title += " to $displayPhoneNumber";
      }
    } else if (call.status == 'initiated') {
      iconData = Icons.phone_forwarded;
      title = "Call to $displayPhoneNumber";
    } else {
      iconData = Icons.phone_missed;
      title = "Missed call to $displayPhoneNumber";
    }

    // Create a dismissible widget for swipe-to-delete functionality
    return Dismissible(
      key: Key(call.callId),
      background: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              "Delete",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ],
        ),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        await _showDeleteConfirmationDialog(call.callId);
        return false; // We handle the dismissal manually
      },
      child: InkWell(
        onTap: () {
          // Navigate to the call details page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CallDetailsPage(callDetails: call),
            ),
          ).then((_) {
            // Refresh the call history when returning from the details page
            _loadAllCallHistory();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lightGreen.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconData,
                  color: primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_formatDateTime(call.createdAt)}${call.callLength > 0 ? ' • ${call.callLength.toStringAsFixed(1)} min' : ''}",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              // Show refresh badge for initiated calls or status indicator for others
              call.status == 'initiated'
                  ? Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "PENDING",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                        ),
                      ),
                    )
                  : Icon(
                      call.status == 'completed'
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 16,
                      color: call.status == 'completed'
                          ? primaryGreen
                          : Colors.redAccent,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGreen,
      appBar: AppBar(
        title: const Text(
          "Recent Activity",
          style: TextStyle(
            color: primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryGreen),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Add clear all button if there are items
          if (_allCallHistory.isNotEmpty && !_isLoading)
            IconButton(
              icon: const Icon(
                Icons.delete_sweep,
                color: primaryGreen,
              ),
              onPressed: _showClearAllConfirmationDialog,
              tooltip: "Clear all activity",
            ),
          IconButton(
            icon: const Icon(
              Icons.refresh,
              color: primaryGreen,
            ),
            onPressed: _refreshCallHistory,
            tooltip: "Refresh activity",
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refreshCallHistory,
              color: primaryGreen,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: primaryGreen,
                      ),
                    )
                  : _allCallHistory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.history,
                                size: 64,
                                color: Colors.black26,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "No activity history",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Your call history will appear here",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black38,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _refreshCallHistory,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  "Refresh",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _allCallHistory.length,
                          itemBuilder: (context, index) {
                            return Column(
                              children: [
                                _buildCallHistoryItem(_allCallHistory[index]),
                                if (index < _allCallHistory.length - 1)
                                  Divider(
                                    height: 32,
                                    color: Colors.grey.withOpacity(0.2),
                                  ),
                              ],
                            );
                          },
                        ),
            ),
            // Show loading overlay when deleting
            if (_isDeleting)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
