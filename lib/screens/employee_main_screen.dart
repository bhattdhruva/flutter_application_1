import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/widgets/custom_search_header.dart';
import 'package:flutter_application_1/widgets/floating_pill_nav_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeMainScreen extends StatefulWidget {
  const EmployeeMainScreen({super.key});

  @override
  State<EmployeeMainScreen> createState() =>
      _EmployeeMainScreenState();
}

class _EmployeeMainScreenState
    extends State<EmployeeMainScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  int _selectedIndex = 0;

  bool _isLoading = true;
  bool _isProcessingAttendance = false;
  bool _isCheckedIn = false;

  String? _errorMessage;

  Map<String, dynamic>? _employee;
  Map<String, dynamic>? _company;

  List<Map<String, dynamic>> _attendanceRecords = [];

  List<Map<String, dynamic>> _leaveRecords = [];

  DateTime? _checkInTime;

  @override
  void initState() {
    super.initState();
    _loadEmployeeData();
  }

  // ============================================================
  // LOAD EMPLOYEE + COMPANY + ATTENDANCE + LEAVE
  // ============================================================

  Future<void> _loadEmployeeData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final user = _supabase.auth.currentUser;

      debugPrint('=================================');
      debugPrint('CURRENT USER ID: ${user?.id}');
      debugPrint('CURRENT USER EMAIL: ${user?.email}');
      debugPrint('=================================');

      if (user == null) {
        throw Exception(
          'Employee is not logged in.',
        );
      }

      // --------------------------------------------------------
      // STEP 1: EMPLOYEE
      // --------------------------------------------------------

      final employeeResponse = await _supabase
          .from('employees')
          .select(
            'id, employee_code, full_name, auth_user_id, company_id',
          )
          .eq('auth_user_id', user.id)
          .limit(1);

      if (employeeResponse.isEmpty) {
        throw Exception(
          'No employee record is linked to this login account.',
        );
      }

      final employee =
          Map<String, dynamic>.from(
        employeeResponse.first,
      );

      debugPrint(
        'EMPLOYEE FOUND: $employee',
      );

      final employeeId =
          employee['id']?.toString();

      final companyId =
          employee['company_id']?.toString();

      if (employeeId == null ||
          employeeId.isEmpty) {
        throw Exception(
          'Employee ID is missing.',
        );
      }

      if (companyId == null ||
          companyId.isEmpty) {
        throw Exception(
          'This employee is not assigned to a company.',
        );
      }

      // --------------------------------------------------------
      // STEP 2: COMPANY
      // --------------------------------------------------------

      final companyResponse = await _supabase
          .from('companies')
          .select(
            'id, name, latitude, longitude, allowed_radius',
          )
          .eq('id', companyId)
          .limit(1);

      if (companyResponse.isEmpty) {
        throw Exception(
          'Company record was not found or you do not have permission to view it.',
        );
      }

      final company =
          Map<String, dynamic>.from(
        companyResponse.first,
      );

      debugPrint(
        'COMPANY FOUND: $company',
      );

      // --------------------------------------------------------
      // STEP 3: ATTENDANCE
      // --------------------------------------------------------

      final attendanceResponse =
          await _supabase
              .from('attendance')
              .select(
                '''
                id,
                employee_id,
                company_id,
                punch_in,
                punch_out,
                punch_in_latitude,
                punch_in_longitude,
                punch_out_latitude,
                punch_out_longitude,
                created_at
                ''',
              )
              .eq(
                'employee_id',
                employeeId,
              )
              .order(
                'created_at',
                ascending: false,
              );

      final attendance =
          List<Map<String, dynamic>>.from(
        attendanceResponse.map(
          (item) =>
              Map<String, dynamic>.from(item),
        ),
      );

      // --------------------------------------------------------
      // STEP 4: FIND OPEN ATTENDANCE
      // --------------------------------------------------------

      Map<String, dynamic>? openAttendance;

      for (final record in attendance) {
        final punchIn =
            record['punch_in'];

        final punchOut =
            record['punch_out'];

        if (punchIn != null &&
            punchOut == null) {
          openAttendance = record;
          break;
        }
      }

      DateTime? currentCheckInTime;

      if (openAttendance != null) {
        final punchIn =
            openAttendance['punch_in'];

        if (punchIn != null) {
          currentCheckInTime =
              DateTime.tryParse(
            punchIn.toString(),
          );
        }
      }

      // --------------------------------------------------------
      // STEP 5: LEAVE REQUESTS
      // --------------------------------------------------------

      final leaveResponse =
          await _supabase
              .from('leave_requests')
              .select(
                '''
                id,
                employee_id,
                company_id,
                leave_type,
                start_date,
                end_date,
                reason,
                status,
                admin_note,
                reviewed_by,
                reviewed_at,
                created_at
                ''',
              )
              .eq(
                'employee_id',
                employeeId,
              )
              .order(
                'created_at',
                ascending: false,
              );

      final leaveRecords =
          List<Map<String, dynamic>>.from(
        leaveResponse.map(
          (item) =>
              Map<String, dynamic>.from(item),
        ),
      );

      debugPrint(
        'LEAVE REQUESTS FOUND: ${leaveRecords.length}',
      );

      if (!mounted) return;

      setState(() {
        _employee = employee;
        _company = company;
        _attendanceRecords = attendance;
        _leaveRecords = leaveRecords;

        _isCheckedIn =
            openAttendance != null;

        _checkInTime =
            currentCheckInTime;

        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint(
        'EMPLOYEE LOAD ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                );
      });
    }
  }

  // ============================================================
  // LOCATION
  // ============================================================

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled. Please turn on GPS/location services.',
      );
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission ==
        LocationPermission.denied) {
      throw Exception(
        'Location permission was denied.',
      );
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. '
        'Please enable location permission from phone settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  // ============================================================
  // CHECK IN / CHECK OUT
  // ============================================================

  Future<void> _handleAttendanceAction() async {
    if (_isProcessingAttendance) {
      return;
    }

    if (_employee == null ||
        _company == null) {
      _showMessage(
        'Employee or company information is not loaded.',
      );
      return;
    }

    setState(() {
      _isProcessingAttendance = true;
    });

    try {
      final position =
          await _getCurrentPosition();

      final companyLatitude =
          (_company!['latitude'] as num)
              .toDouble();

      final companyLongitude =
          (_company!['longitude'] as num)
              .toDouble();

      final allowedRadius =
          (_company!['allowed_radius'] as num)
              .toDouble();

      final distance =
          Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        companyLatitude,
        companyLongitude,
      );

      debugPrint(
        'Employee location: '
        '${position.latitude}, ${position.longitude}',
      );

      debugPrint(
        'Company location: '
        '$companyLatitude, $companyLongitude',
      );

      debugPrint(
        'Distance from company: '
        '${distance.toStringAsFixed(2)} meters',
      );

      if (distance > allowedRadius) {
        throw Exception(
          'You are outside the allowed company location.\n'
          'Distance: ${distance.toStringAsFixed(0)} m\n'
          'Allowed: ${allowedRadius.toStringAsFixed(0)} m',
        );
      }

      final wasCheckedIn =
          _isCheckedIn;

      if (wasCheckedIn) {
        await _checkOut(position);
      } else {
        await _checkIn(position);
      }

      await _loadEmployeeData();

      if (!mounted) return;

      _showMessage(
        wasCheckedIn
            ? 'Checked out successfully.'
            : 'Checked in successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      final message =
          e.toString().replaceFirst(
                'Exception: ',
                '',
              );

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAttendance = false;
        });
      }
    }
  }

  // ============================================================
  // CHECK IN
  // ============================================================

  Future<void> _checkIn(
    Position position,
  ) async {
    final employeeId =
        _employee!['id'];

    final companyId =
        _company!['id'];

    final openAttendance =
        await _supabase
            .from('attendance')
            .select('id')
            .eq(
              'employee_id',
              employeeId,
            )
            .isFilter(
              'punch_out',
              null,
            )
            .order(
              'created_at',
              ascending: false,
            )
            .limit(1)
            .maybeSingle();

    if (openAttendance != null) {
      throw Exception(
        'You already have an active attendance record.',
      );
    }

    await _supabase
        .from('attendance')
        .insert({
      'employee_id': employeeId,
      'company_id': companyId,
      'punch_in':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
      'punch_in_latitude':
          position.latitude,
      'punch_in_longitude':
          position.longitude,
    });
  }

  // ============================================================
  // CHECK OUT
  // ============================================================

  Future<void> _checkOut(
    Position position,
  ) async {
    final employeeId =
        _employee!['id'];

    final openAttendance =
        await _supabase
            .from('attendance')
            .select('id')
            .eq(
              'employee_id',
              employeeId,
            )
            .isFilter(
              'punch_out',
              null,
            )
            .order(
              'created_at',
              ascending: false,
            )
            .limit(1)
            .maybeSingle();

    if (openAttendance == null) {
      throw Exception(
        'No active check-in record was found.',
      );
    }

    await _supabase
        .from('attendance')
        .update({
      'punch_out':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
      'punch_out_latitude':
          position.latitude,
      'punch_out_longitude':
          position.longitude,
    }).eq(
      'id',
      openAttendance['id'],
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        duration:
            const Duration(seconds: 4),
      ),
    );
  }

  // ============================================================
  // DATE / TIME HELPERS
  // ============================================================

  DateTime? _parseDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal();
  }

  String _dateOnlyString(
    DateTime date,
  ) {
    final year =
        date.year.toString().padLeft(4, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final day =
        date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _formatDate(
    DateTime? date,
  ) {
    if (date == null) {
      return '--';
    }

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
      'Dec',
    ];

    return '${months[date.month - 1]} '
        '${date.day}, '
        '${date.year}';
  }

  String _formatLeaveDate(
    dynamic value,
  ) {
    if (value == null) {
      return '--';
    }

    final date =
        DateTime.tryParse(
      value.toString(),
    );

    if (date == null) {
      return value.toString();
    }

    return _formatDate(date);
  }

  String _formatTime(
    DateTime? date,
  ) {
    if (date == null) {
      return '--';
    }

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final minute =
        date.minute
            .toString()
            .padLeft(2, '0');

    final period =
        date.hour >= 12
            ? 'PM'
            : 'AM';

    return '$hour:$minute $period';
  }

  String _formatDuration(
    DateTime? punchIn,
    DateTime? punchOut,
  ) {
    if (punchIn == null) {
      return '--';
    }

    final end =
        punchOut ?? DateTime.now();

    final difference =
        end.difference(punchIn);

    if (difference.isNegative) {
      return '--';
    }

    final hours =
        difference.inHours;

    final minutes =
        difference.inMinutes
            .remainder(60);

    return '${hours}h ${minutes}m';
  }

  String _todayText() {
    final now =
        DateTime.now();

    const weekdays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];

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
      'Dec',
    ];

    return 'Today is '
        '${weekdays[now.weekday - 1]}, '
        '${months[now.month - 1]} '
        '${now.day}';
  }

  // ============================================================
  // ATTENDANCE CALCULATIONS
  // ============================================================

  int _presentDays() {
    final dates = <String>{};

    for (final record
        in _attendanceRecords) {
      final punchIn =
          _parseDateTime(
        record['punch_in'],
      );

      if (punchIn != null) {
        dates.add(
          '${punchIn.year}-'
          '${punchIn.month}-'
          '${punchIn.day}',
        );
      }
    }

    return dates.length;
  }

  Duration _totalWorkedDuration() {
    Duration total =
        Duration.zero;

    for (final record
        in _attendanceRecords) {
      final punchIn =
          _parseDateTime(
        record['punch_in'],
      );

      final punchOut =
          _parseDateTime(
        record['punch_out'],
      );

      if (punchIn != null &&
          punchOut != null) {
        final duration =
            punchOut.difference(
          punchIn,
        );

        if (!duration.isNegative) {
          total += duration;
        }
      }
    }

    return total;
  }

  String _totalWorkedHoursText() {
    final duration =
        _totalWorkedDuration();

    final hours =
        duration.inHours;

    final minutes =
        duration.inMinutes
            .remainder(60);

    return '${hours}h ${minutes}m';
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await _supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const LogInScreen(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title:
              const Text('Employee'),
        ),
        body: Center(
          child: Padding(
            padding:
                const EdgeInsets.all(24),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                ),
                const SizedBox(
                  height: 16,
                ),
                Text(
                  _errorMessage!,
                  textAlign:
                      TextAlign.center,
                ),
                const SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                  onPressed:
                      _loadEmployeeData,
                  child:
                      const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeTab(),
            _buildAttendanceTab(),
            _buildLeaveTab(),
            _buildProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar:
          FloatingPillNavBar(
        currentIndex:
            _selectedIndex,
        items: const [
          FloatingNavItem(
            icon:
                Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Home',
          ),
          FloatingNavItem(
            icon: Icons
                .access_time_outlined,
            activeIcon:
                Icons.access_time,
            label: 'Attendance',
          ),
          FloatingNavItem(
            icon:
                Icons.event_outlined,
            activeIcon: Icons.event,
            label: 'Leave',
          ),
          FloatingNavItem(
            icon:
                Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile',
          ),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  // ============================================================
  // HOME TAB
  // ============================================================

  Widget _buildHomeTab() {
    final employeeName =
        _employee?['full_name']
                ?.toString() ??
            'Employee';

    final companyName =
        _company?['name']
                ?.toString() ??
            'Company';

    final presentDays =
        _presentDays();

    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        110,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          CustomSearchHeader(
            title: 'Employee',
            subtitle: companyName,
            titleIcon:
                Icons.person_outline,
            searchHint: 'Search...',
            onSearchChanged: (_) {},
          ),

          const SizedBox(
            height: 28,
          ),

          Text(
            'Welcome back, '
            '$employeeName!',
            style: const TextStyle(
              fontSize: 26,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            _todayText(),
            style: TextStyle(
              fontSize: 15,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 24,
          ),

          // ==================================================
          // CHECK IN CARD
          // ==================================================

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(22),
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                24,
              ),
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.08),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,
                        color: Theme.of(
                          context,
                        )
                            .colorScheme
                            .primary,
                      ),
                      child: Icon(
                        _isCheckedIn
                            ? Icons.login
                            : Icons.location_on,
                        color:
                            Colors.white,
                      ),
                    ),

                    const SizedBox(
                      width: 14,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            _isCheckedIn
                                ? 'You are checked in'
                                : 'Ready to check in?',
                            style:
                                const TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            _isCheckedIn
                                ? 'Your attendance is active.'
                                : 'GPS location will be checked.',
                            style:
                                TextStyle(
                              color: Colors
                                  .grey
                                  .shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 20,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height: 52,
                  child:
                      ElevatedButton.icon(
                    onPressed:
                        _isProcessingAttendance
                            ? null
                            : _handleAttendanceAction,
                    icon:
                        _isProcessingAttendance
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : Icon(
                                _isCheckedIn
                                    ? Icons.logout
                                    : Icons.login,
                              ),
                    label: Text(
                      _isProcessingAttendance
                          ? 'Checking location...'
                          : _isCheckedIn
                              ? 'Check Out'
                              : 'Check In',
                    ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Text(
                  'Allowed company radius: '
                  '${_company?['allowed_radius'] ?? 200} meters',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 24,
          ),

          // ==================================================
          // STATS
          // ==================================================

          Row(
            children: [
              Expanded(
                child:
                    _buildStatCard(
                  icon:
                      Icons.calendar_today,
                  value:
                      '$presentDays',
                  label:
                      'Present Days',
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child:
                    _buildStatCard(
                  icon:
                      Icons.access_time,
                  value:
                      _totalWorkedHoursText(),
                  label:
                      'Hours Worked',
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child:
                    _buildStatCard(
                  icon:
                      Icons.event_available,
                  value: '--',
                  label:
                      'Leave Left',
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 28,
          ),

          // ==================================================
          // RECENT ACTIVITY
          // ==================================================

          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 1;
                  });
                },
                child:
                    const Text('View All'),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          if (_attendanceRecords
              .isEmpty)
            _buildEmptyCard(
              icon:
                  Icons.access_time,
              title:
                  'No attendance yet',
              subtitle:
                  'Your attendance records will appear here.',
            )
          else
            ..._attendanceRecords
                .take(3)
                .map(
                  _buildAttendanceCard,
                ),
        ],
      ),
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            value,
            style:
                const TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 3,
          ),
          Text(
            label,
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color:
                  Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ATTENDANCE TAB
  // ============================================================

  Widget _buildAttendanceTab() {
    return RefreshIndicator(
      onRefresh:
          _loadEmployeeData,
      child: ListView(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          110,
        ),
        children: [
          CustomSearchHeader(
            title: 'Attendance',
            subtitle:
                'Your attendance history',
            titleIcon:
                Icons.access_time,
            searchHint:
                'Search attendance...',
            onSearchChanged: (_) {},
          ),

          const SizedBox(
            height: 24,
          ),

          if (_attendanceRecords
              .isEmpty)
            _buildEmptyCard(
              icon:
                  Icons.calendar_month,
              title:
                  'No attendance records',
              subtitle:
                  'Check in to create your first attendance record.',
            )
          else
            ..._attendanceRecords.map(
              _buildAttendanceCard,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // ATTENDANCE CARD
  // ============================================================

  Widget _buildAttendanceCard(
    Map<String, dynamic> record,
  ) {
    final punchIn =
        _parseDateTime(
      record['punch_in'],
    );

    final punchOut =
        _parseDateTime(
      record['punch_out'],
    );

    final isOpen =
        punchIn != null &&
            punchOut == null;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 18,
              ),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                child: Text(
                  _formatDate(
                    punchIn,
                  ),
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius
                          .circular(
                    20,
                  ),
                  color: isOpen
                      ? Colors.orange
                          .withOpacity(
                          0.12,
                        )
                      : Colors.green
                          .withOpacity(
                          0.12,
                        ),
                ),
                child: Text(
                  isOpen
                      ? 'Working'
                      : 'Completed',
                  style:
                      TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight
                            .w600,
                    color: isOpen
                        ? Colors.orange
                            .shade800
                        : Colors.green
                            .shade800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          Row(
            children: [
              Expanded(
                child:
                    _buildTimeInfo(
                  icon:
                      Icons.login,
                  title:
                      'Check In',
                  value:
                      _formatTime(
                    punchIn,
                  ),
                ),
              ),

              Expanded(
                child:
                    _buildTimeInfo(
                  icon:
                      Icons.logout,
                  title:
                      'Check Out',
                  value:
                      _formatTime(
                    punchOut,
                  ),
                ),
              ),

              Expanded(
                child:
                    _buildTimeInfo(
                  icon:
                      Icons.access_time,
                  title:
                      'Duration',
                  value:
                      _formatDuration(
                    punchIn,
                    punchOut,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 15,
            ),
            const SizedBox(
              width: 4,
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color:
                    Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 5,
        ),
        Text(
          value,
          style:
              const TextStyle(
            fontSize: 13,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LEAVE TAB
  // ============================================================

  Widget _buildLeaveTab() {
    final companyName =
        _company?['name']
                ?.toString() ??
            'Company';

    return RefreshIndicator(
      onRefresh:
          _loadEmployeeData,
      child: ListView(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          110,
        ),
        children: [
          CustomSearchHeader(
            title: 'Leave',
            subtitle: companyName,
            titleIcon:
                Icons.event_outlined,
            searchHint:
                'Search leave...',
            onSearchChanged: (_) {},
          ),

          const SizedBox(
            height: 24,
          ),

          SizedBox(
            width:
                double.infinity,
            height: 50,
            child:
                ElevatedButton.icon(
              onPressed:
                  _showLeaveDialog,
              icon:
                  const Icon(Icons.add),
              label:
                  const Text(
                'Apply for Leave',
              ),
            ),
          ),

          const SizedBox(
            height: 24,
          ),

          const Text(
            'Leave Requests',
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          if (_leaveRecords
              .isEmpty)
            _buildEmptyCard(
              icon:
                  Icons.event_busy,
              title:
                  'No leave requests',
              subtitle:
                  'Your leave requests will appear here.',
            )
          else
            ..._leaveRecords.map(
              _buildLeaveCard,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // LEAVE CARD
  // ============================================================

  Widget _buildLeaveCard(
    Map<String, dynamic> leave,
  ) {
    final rawStatus =
        leave['status']
                ?.toString() ??
            'pending';

    final status =
        _displayLeaveStatus(
      rawStatus,
    );

    Color statusColor;

    switch (rawStatus.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green;
        break;

      case 'rejected':
        statusColor = Colors.red;
        break;

      default:
        statusColor = Colors.orange;
    }

    final leaveType =
        leave['leave_type']
                ?.toString() ??
            leave['type']
                ?.toString() ??
            'Leave';

    final startDate =
        leave['start_date'] ??
            leave['start'];

    final endDate =
        leave['end_date'] ??
            leave['end'];

    final reason =
        leave['reason']?.toString();

    final adminNote =
        leave['admin_note']
            ?.toString();

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  leaveType,
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius
                          .circular(
                    20,
                  ),
                  color: statusColor
                      .withOpacity(
                    0.12,
                  ),
                ),
                child: Text(
                  status,
                  style:
                      TextStyle(
                    color:
                        statusColor,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color:
                    Colors.grey.shade600,
              ),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                child: Text(
                  '${_formatLeaveDate(startDate)}'
                  ' - '
                  '${_formatLeaveDate(endDate)}',
                  style: TextStyle(
                    color:
                        Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),

          if (reason != null &&
              reason.isNotEmpty) ...[
            const SizedBox(
              height: 10,
            ),

            Text(
              reason,
              style: TextStyle(
                color:
                    Colors.grey.shade700,
              ),
            ),
          ],

          if (adminNote != null &&
              adminNote.isNotEmpty) ...[
            const SizedBox(
              height: 12,
            ),

            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets.all(
                12,
              ),
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                color: Colors.grey
                    .withOpacity(
                  0.08,
                ),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Icon(
                    Icons
                        .admin_panel_settings_outlined,
                    size: 18,
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child: Text(
                      'Admin note: '
                      '$adminNote',
                      style:
                          const TextStyle(
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _displayLeaveStatus(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Approved';

      case 'rejected':
        return 'Rejected';

      case 'pending':
        return 'Pending';

      default:
        if (status.isEmpty) {
          return 'Pending';
        }

        return status[0].toUpperCase() +
            status.substring(1);
    }
  }

  // ============================================================
  // LEAVE DIALOG
  // ============================================================

  Future<void> _showLeaveDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _LeaveDialog(
          onSubmit: ({
            required String leaveType,
            required DateTime startDate,
            required DateTime endDate,
            required String reason,
          }) async {
            final employeeId =
                _employee?['id']
                    ?.toString();

            final companyId =
                _company?['id']
                    ?.toString();

            if (employeeId == null ||
                employeeId.isEmpty) {
              throw Exception(
                'Employee information is missing.',
              );
            }

            if (companyId == null ||
                companyId.isEmpty) {
              throw Exception(
                'Company information is missing.',
              );
            }

            debugPrint(
              '=================================',
            );
            debugPrint(
              'SUBMITTING LEAVE REQUEST',
            );
            debugPrint(
              'Employee ID: $employeeId',
            );
            debugPrint(
              'Company ID: $companyId',
            );
            debugPrint(
              'Leave Type: $leaveType',
            );
            debugPrint(
              'Start Date: '
              '${_dateOnlyString(startDate)}',
            );
            debugPrint(
              'End Date: '
              '${_dateOnlyString(endDate)}',
            );
            debugPrint(
              'Reason: $reason',
            );
            debugPrint(
              '=================================',
            );

            await _supabase
                .from('leave_requests')
                .insert({
              'employee_id':
                  employeeId,
              'company_id':
                  companyId,
              'leave_type':
                  leaveType,
              'start_date':
                  _dateOnlyString(
                startDate,
              ),
              'end_date':
                  _dateOnlyString(
                endDate,
              ),
              'reason': reason,

              // IMPORTANT:
              // Database constraint expects
              // lowercase status.
              'status': 'pending',
            });

            debugPrint(
              'LEAVE REQUEST SUBMITTED SUCCESSFULLY',
            );

            if (!mounted) return;

            Navigator.of(
              dialogContext,
            ).pop();

            await _loadEmployeeData();

            if (!mounted) return;

            _showMessage(
              'Leave request submitted successfully.',
            );
          },
        );
      },
    );
  }

  // ============================================================
  // PROFILE TAB
  // ============================================================

  Widget _buildProfileTab() {
    final user =
        _supabase.auth.currentUser;

    final employeeName =
        _employee?['full_name']
                ?.toString() ??
            'Employee';

    final employeeCode =
        _employee?['employee_code']
                ?.toString() ??
            '--';

    final companyName =
        _company?['name']
                ?.toString() ??
            '--';

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        110,
      ),
      children: [
        CustomSearchHeader(
          title: 'Profile',
          subtitle:
              'Your account',
          titleIcon:
              Icons.person_outline,
          searchHint: 'Search...',
          onSearchChanged: (_) {},
        ),

        const SizedBox(
          height: 30,
        ),

        Center(
          child: CircleAvatar(
            radius: 46,
            child: Text(
              _getInitials(
                employeeName,
              ),
              style:
                  const TextStyle(
                fontSize: 26,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        Center(
          child: Text(
            employeeName,
            style:
                const TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(
          height: 5,
        ),

        Center(
          child: Text(
            employeeCode,
            style: TextStyle(
              color:
                  Colors.grey.shade600,
            ),
          ),
        ),

        const SizedBox(
          height: 28,
        ),

        _buildProfileInfo(
          icon:
              Icons.email_outlined,
          title: 'Email',
          value:
              user?.email ?? '--',
        ),

        _buildProfileInfo(
          icon:
              Icons.badge_outlined,
          title:
              'Employee Code',
          value:
              employeeCode,
        ),

        _buildProfileInfo(
          icon:
              Icons.business_outlined,
          title: 'Company',
          value:
              companyName,
        ),

        const SizedBox(
          height: 20,
        ),

        OutlinedButton.icon(
          onPressed: _logout,
          icon:
              const Icon(Icons.logout),
          label:
              const Text('Logout'),
        ),
      ],
    );
  }

  // ============================================================
  // INITIALS
  // ============================================================

  String _getInitials(
    String name,
  ) {
    final cleanName =
        name.trim();

    if (cleanName.isEmpty) {
      return 'E';
    }

    final parts =
        cleanName.split(
      RegExp(r'\s+'),
    );

    if (parts.length == 1) {
      final word =
          parts.first;

      return word
          .substring(
            0,
            word.length >= 2
                ? 2
                : 1,
          )
          .toUpperCase();
    }

    return '${parts.first[0]}'
            '${parts.last[0]}'
        .toUpperCase();
  }

  // ============================================================
  // PROFILE INFO
  // ============================================================

  Widget _buildProfileInfo({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(icon),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors
                        .grey.shade600,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  value,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight
                            .w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY CARD
  // ============================================================

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 42,
            color:
                Colors.grey.shade500,
          ),

          const SizedBox(
            height: 14,
          ),

          Text(
            title,
            style:
                const TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            subtitle,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LEAVE DIALOG
// ============================================================================

class _LeaveDialog extends StatefulWidget {
  const _LeaveDialog({
    required this.onSubmit,
  });

  final Future<void> Function({
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) onSubmit;

  @override
  State<_LeaveDialog> createState() =>
      _LeaveDialogState();
}

class _LeaveDialogState
    extends State<_LeaveDialog> {
  final TextEditingController
      _reasonController =
      TextEditingController();

  String _selectedLeaveType =
      'Casual Leave';

  DateTime? _startDate;
  DateTime? _endDate;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  // ============================================================
  // START DATE
  // ============================================================

  Future<void> _selectStartDate() async {
    final today =
        DateTime.now();

    final picked =
        await showDatePicker(
      context: context,
      initialDate:
          _startDate ?? today,
      firstDate: DateTime(
        today.year,
        today.month,
        today.day,
      ),
      lastDate: DateTime(
        today.year + 2,
        12,
        31,
      ),
    );

    if (picked == null ||
        !mounted) {
      return;
    }

    setState(() {
      _startDate = picked;

      if (_endDate != null &&
          _endDate!.isBefore(
            picked,
          )) {
        _endDate = null;
      }
    });
  }

  // ============================================================
  // END DATE
  // ============================================================

  Future<void> _selectEndDate() async {
    final today =
        DateTime.now();

    final minimumDate =
        _startDate ??
            DateTime(
              today.year,
              today.month,
              today.day,
            );

    final picked =
        await showDatePicker(
      context: context,
      initialDate:
          _endDate ?? minimumDate,
      firstDate: minimumDate,
      lastDate: DateTime(
        today.year + 2,
        12,
        31,
      ),
    );

    if (picked == null ||
        !mounted) {
      return;
    }

    setState(() {
      _endDate = picked;
    });
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    if (_startDate == null) {
      _showError(
        'Please select a start date.',
      );
      return;
    }

    if (_endDate == null) {
      _showError(
        'Please select an end date.',
      );
      return;
    }

    if (_endDate!.isBefore(
      _startDate!,
    )) {
      _showError(
        'End date cannot be before start date.',
      );
      return;
    }

    final reason =
        _reasonController.text.trim();

    if (reason.isEmpty) {
      _showError(
        'Please enter a reason.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onSubmit(
        leaveType:
            _selectedLeaveType,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: reason,
      );
    } catch (e) {
      debugPrint(
        'LEAVE SUBMIT ERROR: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      _showError(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        duration:
            const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(
    DateTime date,
  ) {
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
      'Dec',
    ];

    return '${months[date.month - 1]} '
        '${date.day}, '
        '${date.year}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      title: const Text(
        'Apply for Leave',
      ),

      content:
          SingleChildScrollView(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            // --------------------------------------------------
            // LEAVE TYPE
            // --------------------------------------------------

            DropdownButtonFormField<
                String>(
              initialValue:
                  _selectedLeaveType,

              decoration:
                  const InputDecoration(
                labelText:
                    'Leave Type',
                border:
                    OutlineInputBorder(),
              ),

              items: const [
                DropdownMenuItem(
                  value:
                      'Casual Leave',
                  child: Text(
                    'Casual Leave',
                  ),
                ),
                DropdownMenuItem(
                  value:
                      'Sick Leave',
                  child: Text(
                    'Sick Leave',
                  ),
                ),
                DropdownMenuItem(
                  value:
                      'Earned Leave',
                  child: Text(
                    'Earned Leave',
                  ),
                ),
              ],

              onChanged:
                  _isSubmitting
                      ? null
                      : (value) {
                          if (value ==
                              null) {
                            return;
                          }

                          setState(() {
                            _selectedLeaveType =
                                value;
                          });
                        },
            ),

            const SizedBox(
              height: 16,
            ),

            // --------------------------------------------------
            // START DATE
            // --------------------------------------------------

            InkWell(
              onTap:
                  _isSubmitting
                      ? null
                      : _selectStartDate,

              child:
                  InputDecorator(
                decoration:
                    const InputDecoration(
                  labelText:
                      'Start Date',
                  border:
                      OutlineInputBorder(),
                  suffixIcon:
                      Icon(
                    Icons
                        .calendar_today,
                  ),
                ),

                child: Text(
                  _startDate == null
                      ? 'Select start date'
                      : _formatDate(
                          _startDate!,
                        ),
                ),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // --------------------------------------------------
            // END DATE
            // --------------------------------------------------

            InkWell(
              onTap:
                  _isSubmitting
                      ? null
                      : _selectEndDate,

              child:
                  InputDecorator(
                decoration:
                    const InputDecoration(
                  labelText:
                      'End Date',
                  border:
                      OutlineInputBorder(),
                  suffixIcon:
                      Icon(
                    Icons
                        .calendar_today,
                  ),
                ),

                child: Text(
                  _endDate == null
                      ? 'Select end date'
                      : _formatDate(
                          _endDate!,
                        ),
                ),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // --------------------------------------------------
            // REASON
            // --------------------------------------------------

            TextField(
              controller:
                  _reasonController,
              enabled:
                  !_isSubmitting,
              maxLines: 3,
              decoration:
                  const InputDecoration(
                labelText: 'Reason',
                hintText:
                    'Enter reason for leave',
                border:
                    OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),

      // --------------------------------------------------------
      // ACTION BUTTONS
      // --------------------------------------------------------

      actions: [
        TextButton(
          onPressed:
              _isSubmitting
                  ? null
                  : () {
                      Navigator.of(
                        context,
                      ).pop();
                    },
          child:
              const Text('Cancel'),
        ),

        ElevatedButton(
          onPressed:
              _isSubmitting
                  ? null
                  : _submit,

          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                        Colors.white,
                  ),
                )
              : const Text(
                  'Apply',
                ),
        ),
      ],
    );
  }
}