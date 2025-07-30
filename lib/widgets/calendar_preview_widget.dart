import 'package:flutter/material.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/job.dart';
import '../models/casting.dart';
import '../models/test.dart';
import '../models/event.dart';
import '../services/jobs_service.dart';
import '../services/events_service.dart';
import '../services/on_stay_service.dart';
import '../services/meetings_service.dart';
import '../services/options_service.dart';
import '../services/direct_bookings_service.dart';
import '../services/direct_options_service.dart';
import '../services/polaroids_service.dart';
import '../models/on_stay.dart';
import '../models/meeting.dart';
import '../models/option.dart';
import '../models/direct_booking.dart';
import '../models/direct_options.dart';
import '../models/polaroid.dart';

class CalendarPreviewWidget extends StatefulWidget {
  final bool isFullCalendar;

  const CalendarPreviewWidget({
    super.key,
    this.isFullCalendar = false,
  });

  @override
  State<CalendarPreviewWidget> createState() => _CalendarPreviewWidgetState();
}

class _CalendarPreviewWidgetState extends State<CalendarPreviewWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;
  String? _error;
  Map<DateTime, List<dynamic>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    if (widget.isFullCalendar) {
      _loadEvents();
    }
  }

  Future<void> _loadEvents() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load all event types
      final jobs = await JobsService.list();
      final castings = await Casting.list();
      final tests = await Test.list();
      final onStays = await OnStayService.list();
      final meetings = await MeetingsService.list();
      final options = await OptionsService.list();
      final directBookings = await DirectBookingsService.list();
      final directOptions = await DirectOptionsService.list();
      final polaroids = await PolaroidsService.list();

      // Load general events from EventsService
      final eventsService = EventsService();
      final generalEvents = await eventsService.getEvents();

      final events = <DateTime, List<dynamic>>{};

      // Group jobs by date
      for (final job in jobs) {
        try {
          final date = DateTime.parse(job.date);
          final dateKey = DateTime(date.year, date.month, date.day);
          events[dateKey] = [...(events[dateKey] ?? []), job];
        } catch (e) {
          debugPrint('Error parsing job date: ${job.date} - $e');
          continue;
        }
      }

      // Group castings by date
      for (final casting in castings) {
        try {
          final date = DateTime(
            casting.date.year,
            casting.date.month,
            casting.date.day,
          );
          events[date] = [...(events[date] ?? []), casting];
        } catch (e) {
          debugPrint('Error processing casting date: $e');
          continue;
        }
      }

      // Group tests by date
      for (final test in tests) {
        try {
          final date = DateTime(test.date.year, test.date.month, test.date.day);
          events[date] = [...(events[date] ?? []), test];
        } catch (e) {
          debugPrint('Error processing test date: $e');
          continue;
        }
      }

      // Group general events by date
      for (final event in generalEvents) {
        try {
          if (event.date != null) {
            final date = DateTime(
              event.date!.year,
              event.date!.month,
              event.date!.day,
            );
            events[date] = [...(events[date] ?? []), event];
          }
        } catch (e) {
          debugPrint('Error processing general event date: $e');
          continue;
        }
      }

      // Group OnStay events by date
      for (final onStay in onStays) {
        try {
          if (onStay.checkInDate != null) {
            final date = DateTime(
              onStay.checkInDate!.year,
              onStay.checkInDate!.month,
              onStay.checkInDate!.day,
            );
            events[date] = [...(events[date] ?? []), onStay];
          }
        } catch (e) {
          debugPrint('Error processing OnStay date: $e');
          continue;
        }
      }

      // Group Meetings by date
      for (final meeting in meetings) {
        try {
          final date = DateTime.parse(meeting.date);
          final dateKey = DateTime(date.year, date.month, date.day);
          events[dateKey] = [...(events[dateKey] ?? []), meeting];
        } catch (e) {
          debugPrint('Error processing Meeting date: $e');
          continue;
        }
      }

      // Group Options by date
      for (final option in options) {
        try {
          final date = DateTime.parse(option.date);
          final dateKey = DateTime(date.year, date.month, date.day);
          events[dateKey] = [...(events[dateKey] ?? []), option];
        } catch (e) {
          debugPrint('Error processing Option date: $e');
          continue;
        }
      }

      // Group Direct Bookings by date
      for (final directBooking in directBookings) {
        try {
          if (directBooking.date != null) {
            final date = DateTime(
              directBooking.date!.year,
              directBooking.date!.month,
              directBooking.date!.day,
            );
            events[date] = [...(events[date] ?? []), directBooking];
          }
        } catch (e) {
          debugPrint('Error processing DirectBooking date: $e');
          continue;
        }
      }

      // Group Direct Options by date
      for (final directOption in directOptions) {
        try {
          if (directOption.date != null) {
            final date = DateTime(
              directOption.date!.year,
              directOption.date!.month,
              directOption.date!.day,
            );
            events[date] = [...(events[date] ?? []), directOption];
          }
        } catch (e) {
          debugPrint('Error processing DirectOption date: $e');
          continue;
        }
      }

      // Group Polaroids by date
      for (final polaroid in polaroids) {
        try {
          final date = DateTime.parse(polaroid.date);
          final dateKey = DateTime(date.year, date.month, date.day);
          events[dateKey] = [...(events[dateKey] ?? []), polaroid];
        } catch (e) {
          debugPrint('Error processing Polaroid date: $e');
          continue;
        }
      }

      setState(() {
        _events = events;
        _isLoading = false;
      });

      debugPrint(
          '📅 Preview Calendar: Loaded ${events.length} event dates with total events: ${events.values.fold(0, (sum, list) => sum + list.length)}');
    } catch (e) {
      debugPrint('❌ Preview Calendar: Error loading events: $e');
      setState(() {
        _error = 'Failed to load events: $e';
        _isLoading = false;
      });
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  String _getEventTitle(dynamic event) {
    if (event is Job) {
      return event.clientName;
    } else if (event is Casting) {
      return event.clientName ?? 'Casting';
    } else if (event is Test) {
      return event.clientName ?? 'Test';
    } else if (event is Polaroid) {
      return event.clientName;
    } else if (event is Meeting) {
      return event.clientName;
    } else if (event is OnStay) {
      return event.locationName;
    } else if (event is DirectBooking) {
      return event.clientName;
    } else if (event is DirectOptions) {
      return event.clientName;
    } else if (event is Option) {
      return event.clientName;
    } else if (event is Event) {
      // Handle generic Event objects (like OTHER events)
      if (event.clientName != null && event.clientName!.isNotEmpty) {
        return event.clientName!;
      } else if (event.additionalData != null &&
          event.additionalData!['event_name'] != null) {
        return event.additionalData!['event_name'];
      } else {
        return event.type.displayName;
      }
    }
    return 'Untitled';
  }

  String _getTruncatedEventTitle(dynamic event) {
    String title = _getEventTitle(event);
    // Truncate long titles to fit in calendar cells - be very aggressive
    if (title.length > 4) {
      return title.substring(0, 4);
    }
    return title;
  }

  String _getEventType(dynamic event) {
    if (event is Job) return 'Job';
    if (event is Casting) return 'Casting';
    if (event is Test) return 'Test';
    if (event is Event) {
      switch (event.type) {
        case EventType.job:
          return 'Job';
        case EventType.casting:
          return 'Casting';
        case EventType.test:
          return 'Test';
        case EventType.option:
          return 'Option';
        case EventType.directBooking:
          return 'Direct Booking';
        case EventType.directOption:
          return 'Direct Option';
        case EventType.onStay:
          return 'On Stay';
        case EventType.polaroids:
          return 'Polaroids';
        case EventType.meeting:
          return 'Meeting';
        default:
          return 'Event';
      }
    }
    return 'Event';
  }

  String _getEventTime(dynamic event) {
    if (event is Job && event.time != null) {
      return event.time!;
    } else if (event is Event && event.startTime != null) {
      return event.startTime!;
    }
    return 'All day';
  }

  String _getEventLocation(dynamic event) {
    if (event is Job) {
      return event.location.isEmpty ? 'No location specified' : event.location;
    } else if (event is Casting) {
      return event.location ?? 'No location specified';
    } else if (event is Test) {
      return event.location ?? 'No location specified';
    } else if (event is Event) {
      return event.location ?? 'No location specified';
    }
    return 'No location specified';
  }

  Color _getEventColor(dynamic event) {
    if (event is Job) return Colors.blue;
    if (event is Casting) return Colors.purple;
    if (event is Test) return Colors.orange;
    if (event is Event) {
      switch (event.type) {
        case EventType.job:
          return Colors.blue;
        case EventType.casting:
          return Colors.purple;
        case EventType.test:
          return Colors.orange;
        case EventType.option:
          return Colors.green;
        case EventType.directBooking:
          return Colors.red;
        case EventType.directOption:
          return Colors.teal;
        case EventType.onStay:
          return Colors.indigo;
        case EventType.polaroids:
          return Colors.pink;
        case EventType.meeting:
          return Colors.amber;
        default:
          return Colors.grey;
      }
    }
    return Colors.grey;
  }

  Widget _buildCalendarDay(DateTime day, bool isToday, bool isSelected,
      {bool isOutside = false}) {
    final events = _getEventsForDay(day);
    final hasEvents = events.isNotEmpty;

    Color? backgroundColor;
    Color textColor = Colors.white;
    Color eventTextColor = Colors.white;

    if (isSelected) {
      backgroundColor = AppTheme.goldColor;
      textColor = Colors.black;
      eventTextColor = Colors.black;
    } else if (isToday) {
      backgroundColor = AppTheme.goldColor.withValues(alpha: 0.7);
      textColor = Colors.black;
      eventTextColor = Colors.black;
    } else if (isOutside) {
      textColor = Colors.white.withValues(alpha: 0.4);
      eventTextColor = Colors.white.withValues(alpha: 0.4);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Get screen size for responsive design
        final screenWidth = MediaQuery.of(context).size.width;
        final isVerySmall = screenWidth < 360;
        final isSmall = screenWidth < 600;
        final isMobile = screenWidth < 768;

        // Responsive sizing for welcome page calendar - improved for better readability
        double cellWidth = isVerySmall
            ? 40
            : isSmall
                ? 45
                : isMobile
                    ? 50
                    : 55;
        double cellHeight = isVerySmall
            ? 65
            : isSmall
                ? 70
                : isMobile
                    ? 75
                    : 80;
        double dayFontSize = isVerySmall
            ? 12
            : isSmall
                ? 14
                : 16;
        double eventFontSize = isVerySmall
            ? 7
            : isSmall
                ? 8
                : isMobile
                    ? 9
                    : 10;

        return Container(
          margin: EdgeInsets.all(isVerySmall ? 1 : 2),
          padding: EdgeInsets.symmetric(
              vertical: isVerySmall ? 2 : 3, horizontal: isVerySmall ? 1 : 2),
          width: cellWidth,
          height: cellHeight,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(isVerySmall ? 4 : 6),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Day number
              Text(
                '${day.day}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
                  fontSize: dayFontSize,
                ),
              ),

              // Event indicators
              if (hasEvents) ...[
                SizedBox(height: isVerySmall ? 1 : 2),
                Expanded(
                  child: ClipRect(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: isVerySmall ? 1 : 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (events.length == 1) ...[
                            // Show single event name (truncated)
                            Flexible(
                              child: Text(
                                _getTruncatedEventTitle(events.first),
                                style: TextStyle(
                                  color: eventTextColor,
                                  fontSize: eventFontSize,
                                  fontWeight: FontWeight.w500,
                                  height: 1.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ] else ...[
                            // Show event count for multiple events
                            Flexible(
                              child: Text(
                                '${events.length}',
                                style: TextStyle(
                                  color: eventTextColor,
                                  fontSize: eventFontSize,
                                  fontWeight: FontWeight.w600,
                                  height: 1.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showDayEventsDialog(DateTime selectedDate, List<dynamic> events) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Events for ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Card(
                      color: Colors.grey[800],
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getEventColor(event),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          _getEventTitle(event),
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getEventType(event),
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                            if (_getEventTime(event) != 'All day')
                              Text(
                                _getEventTime(event),
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          // Just show event details without edit option
                          _showEventDetailsDialog(context, event);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddEventDialog(selectedDate);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Event'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.goldColor,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEventDetailsDialog(BuildContext context, dynamic event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          _getEventTitle(event),
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildEventDetails(event),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToEditEvent(event);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldColor,
              foregroundColor: Colors.black,
            ),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEventDetails(dynamic event) {
    List<Widget> details = [];

    // Event Type
    details.addAll([
      _buildDetailRow('Type', _getEventType(event)),
      const SizedBox(height: 12),
    ]);

    // Date and Time
    if (event is Job) {
      final date = DateTime.tryParse(event.date);
      details.addAll([
        _buildDetailRow(
            'Date',
            date != null
                ? DateFormat('EEEE, MMMM d, yyyy').format(date)
                : event.date),
        const SizedBox(height: 8),
      ]);
      if (event.time != null) {
        details.addAll([
          _buildDetailRow('Time',
              '${event.time}${event.endTime != null ? ' - ${event.endTime}' : ''}'),
          const SizedBox(height: 8),
        ]);
      }
    } else if (event is Casting) {
      details.addAll([
        _buildDetailRow(
            'Date', DateFormat('EEEE, MMMM d, yyyy').format(event.date)),
        const SizedBox(height: 8),
      ]);
    } else if (event is Test) {
      details.addAll([
        _buildDetailRow(
            'Date', DateFormat('EEEE, MMMM d, yyyy').format(event.date)),
        const SizedBox(height: 8),
      ]);
    } else if (event is Event && event.date != null) {
      details.addAll([
        _buildDetailRow(
            'Date', DateFormat('EEEE, MMMM d, yyyy').format(event.date!)),
        const SizedBox(height: 8),
      ]);
      if (event.startTime != null) {
        details.addAll([
          _buildDetailRow('Time',
              '${event.startTime}${event.endTime != null ? ' - ${event.endTime}' : ''}'),
          const SizedBox(height: 8),
        ]);
      }
    }

    // Location
    final location = _getEventLocation(event);
    if (location.isNotEmpty && location != 'No location') {
      details.addAll([
        _buildDetailRow('Location', location),
        const SizedBox(height: 8),
      ]);
    }

    // Event-specific details
    if (event is Job) {
      details.addAll(_buildJobDetails(event));
    } else if (event is Casting) {
      details.addAll(_buildCastingDetails(event));
    } else if (event is Test) {
      details.addAll(_buildTestDetails(event));
    } else if (event is Polaroid) {
      details.addAll(_buildPolaroidDetails(event));
    } else if (event is Meeting) {
      details.addAll(_buildMeetingDetails(event));
    } else if (event is OnStay) {
      details.addAll(_buildOnStayDetails(event));
    } else if (event is DirectBooking) {
      details.addAll(_buildDirectBookingDetails(event));
    } else if (event is DirectOptions) {
      details.addAll(_buildDirectOptionsDetails(event));
    } else if (event is Option) {
      details.addAll(_buildOptionDetails(event));
    } else if (event is Event) {
      details.addAll(_buildGenericEventDetails(event));
    }

    return details;
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _showAddEventDialog(DateTime selectedDate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Add New Event',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Event Type',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
                hint: const Text(
                  'Select event type',
                  style: TextStyle(color: Colors.grey),
                ),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'option', child: Text('Option')),
                  DropdownMenuItem(value: 'job', child: Text('Job')),
                  DropdownMenuItem(
                      value: 'directOption', child: Text('Direct Option')),
                  DropdownMenuItem(
                      value: 'directBooking', child: Text('Direct Booking')),
                  DropdownMenuItem(value: 'casting', child: Text('Casting')),
                  DropdownMenuItem(value: 'onStay', child: Text('On Stay')),
                  DropdownMenuItem(value: 'test', child: Text('Test')),
                  DropdownMenuItem(
                      value: 'polaroids', child: Text('Polaroids')),
                  DropdownMenuItem(value: 'meeting', child: Text('Meeting')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    Navigator.pop(context);
                    _navigateToEventCreation(value, selectedDate);
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Will be scheduled for ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _navigateToEventCreation(String eventType, DateTime selectedDate) {
    switch (eventType) {
      case 'option':
        Navigator.pushNamed(
          context,
          '/new-option',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'job':
        Navigator.pushNamed(
          context,
          '/new-job',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'directOption':
        Navigator.pushNamed(
          context,
          '/new-direct-option',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'directBooking':
        Navigator.pushNamed(
          context,
          '/new-direct-booking',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'casting':
        Navigator.pushNamed(
          context,
          '/new-casting',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'onStay':
        Navigator.pushNamed(
          context,
          '/new-on-stay',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'test':
        Navigator.pushNamed(
          context,
          '/new-test',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'polaroids':
        Navigator.pushNamed(
          context,
          '/new-polaroid',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'meeting':
        Navigator.pushNamed(
          context,
          '/new-meeting',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'other':
        Navigator.pushNamed(
          context,
          '/new-event',
          arguments: {
            'preselectedDate': selectedDate,
            'eventType': EventType.other
          },
        ).then((_) => _loadEvents());
        break;
      default:
        Navigator.pushNamed(
          context,
          '/new-event',
          arguments: {
            'preselectedDate': selectedDate,
            'eventType': EventType.other
          },
        ).then((_) => _loadEvents());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isFullCalendar) {
      return _buildPreviewCalendar();
    }

    return _buildFullCalendar();
  }

  Widget _buildPreviewCalendar() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900]!.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Month header
          LayoutBuilder(
            builder: (context, constraints) {
              final isVerySmall = constraints.maxWidth < 200;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _getMonthName(currentMonth),
                      style: TextStyle(
                        fontSize: isVerySmall ? 14 : 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentYear.toString(),
                    style: TextStyle(
                      fontSize: isVerySmall ? 12 : 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Weekday headers
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isSmallMobile = screenWidth < 360;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map((day) => Flexible(
                          child: SizedBox(
                            width: isSmallMobile ? 16 : 20,
                            child: Text(
                              day,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isSmallMobile ? 9 : 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 12),

          // Calendar grid - scrollable for one month
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isSmallMobile = screenWidth < 360;
              final calendarHeight = isSmallMobile ? 120.0 : 140.0;
              final dateWidth = isSmallMobile ? 50.0 : 60.0;
              final marginRight = isSmallMobile ? 6.0 : 8.0;

              return SizedBox(
                height: calendarHeight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      DateTime(currentYear, currentMonth + 1, 0).day,
                      (index) {
                        final dayNumber = index + 1;
                        final cellDate =
                            DateTime(currentYear, currentMonth, dayNumber);
                        final isToday = cellDate.day == now.day &&
                            cellDate.month == now.month &&
                            cellDate.year == now.year;
                        final isPast = cellDate
                            .isBefore(DateTime(now.year, now.month, now.day));
                        final events = _getEventsForDay(cellDate);
                        final hasEvents = events.isNotEmpty;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDay = cellDate;
                            });
                            if (hasEvents) {
                              _showDayEventsDialog(cellDate, events);
                            } else {
                              _showAddEventDialog(cellDate);
                            }
                          },
                          child: Container(
                            width: dateWidth,
                            margin: EdgeInsets.only(right: marginRight),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? AppTheme.goldColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallMobile ? 2 : 4,
                                vertical: isSmallMobile ? 4 : 6,
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Weekday
                                  Text(
                                    _getWeekdayName(cellDate.weekday),
                                    style: TextStyle(
                                      fontSize: isSmallMobile ? 7 : 9,
                                      color: isToday
                                          ? Colors.black
                                          : Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),

                                  // Day number
                                  Text(
                                    dayNumber.toString(),
                                    style: TextStyle(
                                      fontSize: isSmallMobile ? 14 : 16,
                                      fontWeight: isToday
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isToday
                                          ? Colors.black
                                          : isPast
                                              ? Colors.white
                                                  .withValues(alpha: 0.4)
                                              : Colors.white,
                                    ),
                                  ),

                                  // Event indicators section
                                  SizedBox(
                                    height: isSmallMobile ? 18 : 22,
                                    child: hasEvents
                                        ? Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              if (events.length == 1) ...[
                                                Text(
                                                  _getEventTitle(events.first),
                                                  style: TextStyle(
                                                    fontSize:
                                                        isSmallMobile ? 7 : 9,
                                                    fontWeight: FontWeight.w600,
                                                    color: isToday
                                                        ? Colors.black
                                                        : Colors.white,
                                                    height: 1.1,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                ),
                                              ] else ...[
                                                Text(
                                                  '+${events.length}',
                                                  style: TextStyle(
                                                    fontSize:
                                                        isSmallMobile ? 8 : 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: isToday
                                                        ? Colors.black
                                                        : Colors.white,
                                                    height: 1.0,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ],
                                          )
                                        : const SizedBox.shrink(),
                                  ),

                                  // Month
                                  Text(
                                    _getMonthAbbr(currentMonth),
                                    style: TextStyle(
                                      fontSize: isSmallMobile ? 7 : 9,
                                      color: isToday
                                          ? Colors.black
                                          : Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(AppTheme.goldColor, 'Today'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFullCalendar() {
    if (_isLoading) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.goldColor),
        ),
      );
    }

    if (_error != null) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900]!.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Calendar header with add button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isVerySmall = constraints.maxWidth < 300;
                final isSmall = constraints.maxWidth < 400;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Your Schedule',
                        style: TextStyle(
                          fontSize: isVerySmall
                              ? 14
                              : isSmall
                                  ? 16
                                  : 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isVerySmall)
                      // Very small screens: Icon only button
                      ElevatedButton(
                        onPressed: () =>
                            _showAddEventDialog(_selectedDay ?? DateTime.now()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.goldColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(32, 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Icon(Icons.add, size: 16),
                      )
                    else if (isSmall)
                      // Small screens: Compact button
                      ElevatedButton(
                        onPressed: () =>
                            _showAddEventDialog(_selectedDay ?? DateTime.now()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.goldColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          textStyle: const TextStyle(fontSize: 10),
                        ),
                        child: const Text('Add'),
                      )
                    else
                      // Normal screens: Full button
                      ElevatedButton.icon(
                        onPressed: () =>
                            _showAddEventDialog(_selectedDay ?? DateTime.now()),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Event'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.goldColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          // Table Calendar with responsive constraints
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isVerySmall = screenWidth < 300;
              final isSmall = screenWidth < 400;

              return SizedBox(
                width: constraints.maxWidth,
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.month,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: _getEventsForDay,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  calendarStyle: CalendarStyle(
                    markersMaxCount:
                        0, // Disable default markers since we use custom builders
                    todayDecoration: const BoxDecoration(
                      color: Colors.transparent, // Handled by custom builder
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: Colors.transparent, // Handled by custom builder
                    ),
                    defaultDecoration: const BoxDecoration(
                      color: Colors.transparent, // Handled by custom builder
                    ),
                    outsideDaysVisible: false,
                    canMarkersOverflow: false,
                    weekendTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: isVerySmall ? 12 : 14,
                    ),
                    defaultTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: isVerySmall ? 12 : 14,
                    ),
                    cellMargin: EdgeInsets.all(isVerySmall ? 2 : 3),
                    cellPadding: const EdgeInsets.all(0),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(day, false, false);
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(day, true, false);
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(day, false, true);
                    },
                    outsideBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(day, false, false,
                          isOutside: true);
                    },
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: isVerySmall
                          ? 14
                          : isSmall
                              ? 15
                              : 16,
                      fontWeight: FontWeight.w600,
                    ),
                    leftChevronIcon: Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: isVerySmall ? 20 : 24,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: isVerySmall ? 20 : 24,
                    ),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      color: Colors.white70,
                      fontSize: isVerySmall ? 10 : 12,
                    ),
                    weekendStyle: TextStyle(
                      color: Colors.white70,
                      fontSize: isVerySmall ? 10 : 12,
                    ),
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });

                    // Show events for the selected day
                    final events = _getEventsForDay(selectedDay);
                    if (events.isNotEmpty) {
                      _showDayEventsDialog(selectedDay, events);
                    } else {
                      _showAddEventDialog(selectedDay);
                    }
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[weekday - 1];
  }

  String _getMonthAbbr(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  // Event-specific detail builders
  List<Widget> _buildJobDetails(Job job) {
    List<Widget> details = [];

    if (job.type.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Job Type', job.type),
        const SizedBox(height: 8),
      ]);
    }

    if (job.rate > 0) {
      details.addAll([
        _buildDetailRow(
            'Rate', '${job.currency ?? 'USD'} ${job.rate.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    if (job.extraHours != null && job.extraHours! > 0) {
      details.addAll([
        _buildDetailRow(
            'Extra Hours', '${job.extraHours!.toStringAsFixed(1)} hours'),
        const SizedBox(height: 8),
      ]);
    }

    if (job.bookingAgent != null && job.bookingAgent!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Booking Agent', job.bookingAgent!),
        const SizedBox(height: 8),
      ]);
    }

    if (job.status != null && job.status!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Status', job.status!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    if (job.paymentStatus != null && job.paymentStatus!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Payment', job.paymentStatus!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    if (job.notes != null && job.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', job.notes!),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  List<Widget> _buildCastingDetails(Casting casting) {
    List<Widget> details = [];

    if (casting.title.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Title', casting.title),
        const SizedBox(height: 8),
      ]);
    }

    if (casting.description != null && casting.description!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Description', casting.description!),
        const SizedBox(height: 8),
      ]);
    }

    if (casting.requirements != null && casting.requirements!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Requirements', casting.requirements!),
        const SizedBox(height: 8),
      ]);
    }

    if (casting.rate != null && casting.rate! > 0) {
      details.addAll([
        _buildDetailRow('Rate',
            '${casting.currency ?? 'USD'} ${casting.rate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    details.addAll([
      _buildDetailRow('Status', casting.status.toUpperCase()),
      const SizedBox(height: 8),
    ]);

    return details;
  }

  List<Widget> _buildTestDetails(Test test) {
    List<Widget> details = [];

    if (test.title.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Title', test.title),
        const SizedBox(height: 8),
      ]);
    }

    if (test.description != null && test.description!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Description', test.description!),
        const SizedBox(height: 8),
      ]);
    }

    if (test.requirements != null && test.requirements!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Requirements', test.requirements!),
        const SizedBox(height: 8),
      ]);
    }

    if (test.rate != null && test.rate! > 0) {
      details.addAll([
        _buildDetailRow('Rate',
            '${test.currency ?? 'USD'} ${test.rate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    details.addAll([
      _buildDetailRow('Status', test.status.toUpperCase()),
      const SizedBox(height: 8),
    ]);

    return details;
  }

  List<Widget> _buildPolaroidDetails(Polaroid polaroid) {
    List<Widget> details = [];

    if (polaroid.type != null && polaroid.type!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Type', polaroid.type!),
        const SizedBox(height: 8),
      ]);
    }

    if (polaroid.rate != null && polaroid.rate! > 0) {
      details.addAll([
        _buildDetailRow('Rate',
            '${polaroid.currency ?? 'USD'} ${polaroid.rate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    if (polaroid.time != null && polaroid.time!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Time',
            '${polaroid.time}${polaroid.endTime != null ? ' - ${polaroid.endTime}' : ''}'),
        const SizedBox(height: 8),
      ]);
    }

    if (polaroid.bookingAgent != null && polaroid.bookingAgent!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Booking Agent', polaroid.bookingAgent!),
        const SizedBox(height: 8),
      ]);
    }

    if (polaroid.status != null && polaroid.status!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Status', polaroid.status!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    if (polaroid.notes != null && polaroid.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', polaroid.notes!),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  List<Widget> _buildMeetingDetails(Meeting meeting) {
    List<Widget> details = [];

    if (meeting.type != null && meeting.type!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Type', meeting.type!),
        const SizedBox(height: 8),
      ]);
    }

    if (meeting.time != null && meeting.time!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Time',
            '${meeting.time}${meeting.endTime != null ? ' - ${meeting.endTime}' : ''}'),
        const SizedBox(height: 8),
      ]);
    }

    if (meeting.email != null && meeting.email!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Email', meeting.email!),
        const SizedBox(height: 8),
      ]);
    }

    if (meeting.phone != null && meeting.phone!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Phone', meeting.phone!),
        const SizedBox(height: 8),
      ]);
    }

    if (meeting.status != null && meeting.status!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Status', meeting.status!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    if (meeting.notes != null && meeting.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', meeting.notes!),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  List<Widget> _buildOnStayDetails(OnStay onStay) {
    List<Widget> details = [];

    if (onStay.stayType != null && onStay.stayType!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Stay Type', onStay.stayType!),
        const SizedBox(height: 8),
      ]);
    }

    if (onStay.address != null && onStay.address!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Address', onStay.address!),
        const SizedBox(height: 8),
      ]);
    }

    if (onStay.checkInDate != null) {
      details.addAll([
        _buildDetailRow(
            'Check-in', DateFormat('MMM d, yyyy').format(onStay.checkInDate!)),
        const SizedBox(height: 8),
      ]);
    }

    if (onStay.checkOutDate != null) {
      details.addAll([
        _buildDetailRow('Check-out',
            DateFormat('MMM d, yyyy').format(onStay.checkOutDate!)),
        const SizedBox(height: 8),
      ]);
    }

    details.addAll([
      _buildDetailRow(
          'Cost', '${onStay.currency} ${onStay.cost.toStringAsFixed(2)}'),
      const SizedBox(height: 8),
    ]);

    if (onStay.contactName != null && onStay.contactName!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Contact', onStay.contactName!),
        const SizedBox(height: 8),
      ]);
    }

    details.addAll([
      _buildDetailRow('Status', onStay.status.toUpperCase()),
      const SizedBox(height: 8),
    ]);

    return details;
  }

  List<Widget> _buildDirectBookingDetails(DirectBooking directBooking) {
    List<Widget> details = [];

    if (directBooking.bookingType != null &&
        directBooking.bookingType!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Booking Type', directBooking.bookingType!),
        const SizedBox(height: 8),
      ]);
    }

    if (directBooking.rate != null && directBooking.rate! > 0) {
      details.addAll([
        _buildDetailRow('Rate',
            '${directBooking.currency ?? 'USD'} ${directBooking.rate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    if (directBooking.time != null && directBooking.time!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Time',
            '${directBooking.time}${directBooking.endTime != null ? ' - ${directBooking.endTime}' : ''}'),
        const SizedBox(height: 8),
      ]);
    }

    if (directBooking.bookingAgent != null &&
        directBooking.bookingAgent!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Booking Agent', directBooking.bookingAgent!),
        const SizedBox(height: 8),
      ]);
    }

    if (directBooking.status != null && directBooking.status!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Status', directBooking.status!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  List<Widget> _buildDirectOptionsDetails(DirectOptions directOptions) {
    List<Widget> details = [];

    if (directOptions.optionType != null &&
        directOptions.optionType!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Option Type', directOptions.optionType!),
        const SizedBox(height: 8),
      ]);
    }

    if (directOptions.rate != null && directOptions.rate! > 0) {
      details.addAll([
        _buildDetailRow('Rate',
            '${directOptions.currency ?? 'USD'} ${directOptions.rate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    if (directOptions.time != null && directOptions.time!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Time',
            '${directOptions.time}${directOptions.endTime != null ? ' - ${directOptions.endTime}' : ''}'),
        const SizedBox(height: 8),
      ]);
    }

    if (directOptions.bookingAgent != null &&
        directOptions.bookingAgent!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Booking Agent', directOptions.bookingAgent!),
        const SizedBox(height: 8),
      ]);
    }

    if (directOptions.status != null && directOptions.status!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Status', directOptions.status!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  List<Widget> _buildOptionDetails(Option option) {
    List<Widget> details = [];

    if (option.type.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Type', option.type),
        const SizedBox(height: 8),
      ]);
    }

    if (option.rate != null && option.rate! > 0) {
      details.addAll([
        _buildDetailRow('Rate',
            '${option.currency ?? 'USD'} ${option.rate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    if (option.time != null && option.time!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Time',
            '${option.time}${option.endTime != null ? ' - ${option.endTime}' : ''}'),
        const SizedBox(height: 8),
      ]);
    }

    if (option.extraHours != null && option.extraHours! > 0) {
      details.addAll([
        _buildDetailRow(
            'Extra Hours', '${option.extraHours!.toStringAsFixed(1)} hours'),
        const SizedBox(height: 8),
      ]);
    }

    details.addAll([
      _buildDetailRow('Status', option.status.toUpperCase()),
      const SizedBox(height: 8),
    ]);

    details.addAll([
      _buildDetailRow('Payment', option.paymentStatus.toUpperCase()),
      const SizedBox(height: 8),
    ]);

    if (option.notes != null && option.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', option.notes!),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  List<Widget> _buildGenericEventDetails(Event event) {
    List<Widget> details = [];

    if (event.dayRate != null && event.dayRate! > 0) {
      details.addAll([
        _buildDetailRow('Day Rate',
            '${event.currency ?? 'USD'} ${event.dayRate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    if (event.usageRate != null && event.usageRate! > 0) {
      details.addAll([
        _buildDetailRow('Usage Rate',
            '${event.currency ?? 'USD'} ${event.usageRate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    if (event.status != null) {
      details.addAll([
        _buildDetailRow(
            'Status', event.status.toString().split('.').last.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    if (event.paymentStatus != null) {
      details.addAll([
        _buildDetailRow('Payment',
            event.paymentStatus.toString().split('.').last.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    if (event.notes != null && event.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', event.notes!),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  void _navigateToEditEvent(dynamic event) {
    String route;
    Map<String, dynamic> arguments = {};

    if (event is Job) {
      route = '/new-job';
      arguments = {'existingJob': event};
    } else if (event is Casting) {
      route = '/new-casting';
      arguments = {'existingCasting': event};
    } else if (event is Test) {
      route = '/new-test';
      arguments = {'existingTest': event};
    } else if (event is Polaroid) {
      route = '/new-polaroid';
      arguments = {'existingPolaroid': event};
    } else if (event is Meeting) {
      route = '/new-meeting';
      arguments = {'existingMeeting': event};
    } else if (event is OnStay) {
      route = '/new-on-stay';
      arguments = {'existingOnStay': event};
    } else if (event is DirectBooking) {
      route = '/new-direct-booking';
      arguments = {'existingDirectBooking': event};
    } else if (event is DirectOptions) {
      route = '/new-direct-option';
      arguments = {'existingDirectOption': event};
    } else if (event is Option) {
      route = '/new-option';
      arguments = {'existingOption': event};
    } else if (event is Event) {
      route = '/new-event';
      arguments = {'existingEvent': event, 'eventType': event.type};
    } else {
      // Fallback for unknown event types
      return;
    }

    Navigator.pushNamed(context, route, arguments: arguments).then((_) {
      // Reload events after editing
      _loadEvents();
    });
  }
}
