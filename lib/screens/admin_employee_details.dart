import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminEmployeeDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> employee;
  final String companyName;

  const AdminEmployeeDetailsScreen({
    super.key,
    required this.employee,
    required this.companyName,
  });

  @override
  State<AdminEmployeeDetailsScreen> createState() =>
      _AdminEmployeeDetailsScreenState();
}

class _AdminEmployeeDetailsScreenState
    extends State<AdminEmployeeDetailsScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _attendance = [];

  @override
  void initState() {
    super.initState();
    _loadEmployeeAttendance();
  }

  Future<void> _loadEmployeeAttendance() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final employeeId = widget.employee['id'];

      if (employeeId == null) {
        throw Exception('Employee ID not found.');
      }

      final attendance = await supabase
          .from('attendance')
          .select(
            '''
            id,
            punch_in,
            punch_out,
            punch_in_latitude,
            punch_in_longitude,
            punch_out_latitude,
            punch_out_longitude,
            created_at
            ''',
          )
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _attendance = List<Map<String, dynamic>>.from(attendance);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  String _formatDate(String? value) {
    if (value == null) return '--';

    final date = DateTime.tryParse(value);

    if (date == null) return '--';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(String? value) {
    if (value == null) return '--';

    final date = DateTime.tryParse(value)?.toLocal();

    if (date == null) return '--';

    final hour = date.hour;
    final minute = date.minute;

    final period = hour >= 12 ? 'PM' : 'AM';

    final displayHour = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;

    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  String _calculateWorkingHours(
    String? punchIn,
    String? punchOut,
  ) {
    if (punchIn == null || punchOut == null) {
      return '--';
    }

    final inTime = DateTime.tryParse(punchIn);
    final outTime = DateTime.tryParse(punchOut);

    if (inTime == null || outTime == null) {
      return '--';
    }

    final duration = outTime.difference(inTime);

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final name =
        widget.employee['full_name']?.toString() ?? 'Employee';

    final employeeCode =
        widget.employee['employee_code']?.toString() ?? '--';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Employee Details'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadEmployeeAttendance,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildEmployeeHeader(
                        name,
                        employeeCode,
                      ),

                      const SizedBox(height: 20),

                      _buildEmployeeInformation(
                        name,
                        employeeCode,
                      ),

                      const SizedBox(height: 20),

                      _buildAttendanceSummary(),

                      const SizedBox(height: 20),

                      const Text(
                        'Attendance History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (_attendance.isEmpty)
                        _buildNoAttendance()
                      else
                        ..._attendance.map(
                          (record) =>
                              _buildAttendanceCard(record),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmployeeHeader(
    String name,
    String employeeCode,
  ) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFF2E66F6),
              child: Text(
                name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    employeeCode,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    widget.companyName,
                    style: const TextStyle(
                      color: Color(0xFF2E66F6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeInformation(
    String name,
    String employeeCode,
  ) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Employee Information',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            _buildInfoRow(
              Icons.person,
              'Full Name',
              name,
            ),

            _buildInfoRow(
              Icons.badge,
              'Employee Code',
              employeeCode,
            ),

            _buildInfoRow(
              Icons.business,
              'Company',
              widget.companyName,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(
            icon,
            size: 21,
            color: const Color(0xFF2E66F6),
          ),

          const SizedBox(width: 12),

          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),

          const Spacer(),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSummary() {
    final totalDays = _attendance.length;

    final completedDays = _attendance.where((record) {
      return record['punch_in'] != null &&
          record['punch_out'] != null;
    }).length;

    final openDays = _attendance.where((record) {
      return record['punch_in'] != null &&
          record['punch_out'] == null;
    }).length;

    return Row(
      children: [
        _buildSummaryCard(
          'Records',
          '$totalDays',
          Icons.calendar_month,
          Colors.blue,
        ),

        const SizedBox(width: 10),

        _buildSummaryCard(
          'Completed',
          '$completedDays',
          Icons.check_circle,
          Colors.green,
        ),

        const SizedBox(width: 10),

        _buildSummaryCard(
          'Open',
          '$openDays',
          Icons.access_time,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 23,
            ),

            const SizedBox(height: 6),

            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(
    Map<String, dynamic> record,
  ) {
    final punchIn =
        record['punch_in']?.toString();

    final punchOut =
        record['punch_out']?.toString();

    final workingHours =
        _calculateWorkingHours(
      punchIn,
      punchOut,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Color(0xFF2E66F6),
                ),

                const SizedBox(width: 8),

                Text(
                  _formatDate(
                    punchIn ??
                        record['created_at']?.toString(),
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const Spacer(),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: punchOut != null
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    punchOut != null
                        ? 'Completed'
                        : 'Open',
                    style: TextStyle(
                      color: punchOut != null
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            Row(
              children: [
                Expanded(
                  child: _buildPunchTime(
                    'Punch In',
                    _formatTime(punchIn),
                    Icons.login,
                    Colors.green,
                  ),
                ),

                Expanded(
                  child: _buildPunchTime(
                    'Punch Out',
                    _formatTime(punchOut),
                    Icons.logout,
                    Colors.red,
                  ),
                ),

                Expanded(
                  child: _buildPunchTime(
                    'Working',
                    workingHours,
                    Icons.access_time,
                    Colors.blue,
                  ),
                ),
              ],
            ),

            if (record['punch_in_latitude'] != null ||
                record['punch_in_longitude'] != null ||
                record['punch_out_latitude'] != null ||
                record['punch_out_longitude'] != null) ...[
              const SizedBox(height: 16),

              const Divider(),

              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Punch Location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              if (record['punch_in_latitude'] != null)
                _buildLocationRow(
                  'Punch In',
                  record['punch_in_latitude'],
                  record['punch_in_longitude'],
                ),

              if (record['punch_out_latitude'] != null)
                _buildLocationRow(
                  'Punch Out',
                  record['punch_out_latitude'],
                  record['punch_out_longitude'],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPunchTime(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: color,
        ),

        const SizedBox(height: 6),

        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow(
    String title,
    dynamic latitude,
    dynamic longitude,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 18,
            color: Color(0xFF2E66F6),
          ),

          const SizedBox(width: 8),

          Text(
            '$title: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),

          Expanded(
            child: Text(
              '${latitude ?? '--'}, ${longitude ?? '--'}',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAttendance() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.event_busy,
              size: 45,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 10),

            const Text(
              'No attendance records found.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 50,
              color: Colors.red,
            ),

            const SizedBox(height: 15),

            const Text(
              'Unable to load employee data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _loadEmployeeAttendance,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}