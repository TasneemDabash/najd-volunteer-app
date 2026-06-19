import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';
import '../models/volunteer.dart';

class TaskService {
  final SupabaseClient _client = Supabase.instance.client;
  static const String _tasksTable = 'tasks';
  static const String _assignmentsTable = 'task_assignments';

  List<TaskModel> _mapTasks(dynamic response) {
    return (response as List)
        .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<dynamic> _tasksQueryOrdered({
    TaskStatus? status,
    required String orderColumn,
  }) async {
    var query = _client.from(_tasksTable).select();
    if (status != null) {
      query = query.eq('status', status.name);
    }
    return query.order(orderColumn, ascending: false);
  }

  /// Orders by `date` when the column exists; falls back to `created_at`.
  Future<List<TaskModel>> getTasks({TaskStatus? status}) async {
    try {
      final response =
          await _tasksQueryOrdered(status: status, orderColumn: 'date');
      return _mapTasks(response);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('PGRST204') ||
          msg.contains('42703') ||
          (msg.contains('date') &&
              (msg.contains('does not exist') ||
                  msg.contains('schema cache')))) {
        final response = await _tasksQueryOrdered(
            status: status, orderColumn: 'created_at');
        return _mapTasks(response);
      }
      rethrow;
    }
  }

  Future<TaskModel?> getTaskById(String id) async {
    final response =
        await _client.from(_tasksTable).select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return TaskModel.fromJson(response);
  }

  static bool _missingSchemaColumnError(Object e) {
    final s = e.toString();
    return s.contains('PGRST204') ||
        s.contains('42703') ||
        (s.contains('schema cache') && s.contains('column'));
  }

  Map<String, dynamic> _createPayload({
    required String title,
    required String description,
    required String location,
    String? locationId,
    double? latitude,
    double? longitude,
    required List<String> requiredSkills,
    required DateTime date,
    required TaskStatus status,
    bool includeDate = true,
    bool includeLocation = true,
    bool includeDescription = true,
    bool includeRequiredSkills = true,
    bool includeLocationId = true,
    bool includeCoordinates = true,
  }) {
    return {
      'title': title,
      if (includeDescription) 'description': description,
      if (includeLocation) 'location': location,
      if (includeLocationId && locationId != null) 'location_id': locationId,
      if (includeCoordinates && latitude != null) 'latitude': latitude,
      if (includeCoordinates && longitude != null) 'longitude': longitude,
      if (includeRequiredSkills) 'required_skills': requiredSkills,
      'status': status.name,
      if (includeDate) 'date': date.toIso8601String(),
    };
  }

  Future<TaskModel> createTask({
    required String title,
    required String description,
    required String location,
    String? locationId,
    double? latitude,
    double? longitude,
    required List<String> requiredSkills,
    required DateTime date,
    TaskStatus status = TaskStatus.pending,
  }) async {
    final attempts = <Map<String, dynamic>>[
      _createPayload(
        title: title,
        description: description,
        location: location,
        locationId: locationId,
        latitude: latitude,
        longitude: longitude,
        requiredSkills: requiredSkills,
        date: date,
        status: status,
      ),
      _createPayload(
        title: title,
        description: description,
        location: location,
        locationId: locationId,
        latitude: latitude,
        longitude: longitude,
        requiredSkills: requiredSkills,
        date: date,
        status: status,
        includeCoordinates: false,
      ),
      _createPayload(
        title: title,
        description: description,
        location: location,
        locationId: locationId,
        latitude: latitude,
        longitude: longitude,
        requiredSkills: requiredSkills,
        date: date,
        status: status,
        includeLocationId: false,
        includeCoordinates: false,
      ),
      _createPayload(
        title: title,
        description: description,
        location: location,
        requiredSkills: requiredSkills,
        date: date,
        status: status,
        includeDate: false,
        includeLocationId: false,
        includeCoordinates: false,
      ),
      {
        'title': title,
        'required_skills': requiredSkills,
        'status': status.name,
      },
      {'title': title, 'status': status.name},
    ];

    Object? last;
    for (final data in attempts) {
      try {
        final response = await _client
            .from(_tasksTable)
            .insert(data)
            .select()
            .single();
        return TaskModel.fromJson(response);
      } catch (e) {
        last = e;
        if (!_missingSchemaColumnError(e)) rethrow;
      }
    }
    throw last!;
  }

  Map<String, dynamic> _updatePayload(
    TaskModel task, {
    bool includeDate = true,
    bool includeLocation = true,
    bool includeDescription = true,
    bool includeRequiredSkills = true,
    bool includeLocationId = true,
    bool includeCoordinates = true,
  }) {
    return {
      'title': task.title,
      if (includeDescription) 'description': task.description,
      if (includeLocation) 'location': task.location,
      if (includeLocationId && task.locationId != null)
        'location_id': task.locationId,
      if (includeCoordinates && task.latitude != null) 'latitude': task.latitude,
      if (includeCoordinates && task.longitude != null)
        'longitude': task.longitude,
      if (includeRequiredSkills) 'required_skills': task.requiredSkills,
      'status': task.status.name,
      if (includeDate) 'date': task.date.toIso8601String(),
    };
  }

  Future<TaskModel> updateTask(TaskModel task) async {
    final attempts = <Map<String, dynamic>>[
      _updatePayload(task),
      _updatePayload(task, includeCoordinates: false),
      _updatePayload(task, includeLocationId: false, includeCoordinates: false),
      _updatePayload(task,
          includeDate: false,
          includeLocationId: false,
          includeCoordinates: false),
      _updatePayload(task,
          includeDate: false,
          includeLocation: false,
          includeLocationId: false,
          includeCoordinates: false),
      _updatePayload(
        task,
        includeDate: false,
        includeLocation: false,
        includeDescription: false,
        includeLocationId: false,
        includeCoordinates: false,
      ),
      {
        'title': task.title,
        'required_skills': task.requiredSkills,
        'status': task.status.name,
      },
      {'title': task.title, 'status': task.status.name},
    ];

    Object? last;
    for (final data in attempts) {
      try {
        final response = await _client
            .from(_tasksTable)
            .update(data)
            .eq('id', task.id)
            .select()
            .single();
        return TaskModel.fromJson(response);
      } catch (e) {
        last = e;
        if (!_missingSchemaColumnError(e)) rethrow;
      }
    }
    throw last!;
  }

  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    await _client
        .from(_tasksTable)
        .update({'status': status.name}).eq('id', taskId);
  }

  Future<void> deleteTask(String id) async {
    await _client.from(_tasksTable).delete().eq('id', id);
  }

  Future<List<Volunteer>> getAssignedVolunteers(String taskId) async {
    final assignments = await _client
        .from(_assignmentsTable)
        .select('volunteer_id')
        .eq('task_id', taskId);
    if ((assignments as List).isEmpty) return [];
    final ids =
        assignments.map((e) => (e as Map)['volunteer_id'] as String).toList();
    final volunteers =
        await _client.from('profiles').select().inFilter('id', ids);
    return (volunteers as List)
        .map((e) => Volunteer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Replace assignment set. Insert triggers `trg_notify_volunteer_on_assignment`
  /// so volunteers automatically receive an in-app notification.
  Future<void> assignVolunteers(
      String taskId, List<String> volunteerIds) async {
    await _client.from(_assignmentsTable).delete().eq('task_id', taskId);
    if (volunteerIds.isEmpty) return;
    final rows = volunteerIds
        .map((vId) => {'task_id': taskId, 'volunteer_id': vId})
        .toList();
    await _client.from(_assignmentsTable).insert(rows);
  }

  /// Add a single volunteer (kept separate so we can call from "assign more"
  /// flows without rebuilding the whole assignment set).
  Future<void> addVolunteerAssignment(String taskId, String volunteerId) async {
    await _client
        .from(_assignmentsTable)
        .upsert({'task_id': taskId, 'volunteer_id': volunteerId});
  }

  Future<void> removeVolunteerAssignment(
      String taskId, String volunteerId) async {
    await _client
        .from(_assignmentsTable)
        .delete()
        .eq('task_id', taskId)
        .eq('volunteer_id', volunteerId);
  }

  Future<int> getActiveTasksCount() async {
    final response = await _client
        .from(_tasksTable)
        .select('id')
        .inFilter('status', ['pending', 'active']);
    return (response as List).length;
  }

  Future<int> getCompletedTasksCount() async {
    final response =
        await _client.from(_tasksTable).select('id').eq('status', 'completed');
    return (response as List).length;
  }

  /// Get completed tasks count for the current volunteer
  Future<int> getMyCompletedTasksCount() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return 0;
    try {
      final response = await _client
          .from(_assignmentsTable)
          .select('task:tasks!inner(id, status)')
          .eq('volunteer_id', me)
          .eq('tasks.status', 'completed');
      return (response as List).length;
    } catch (_) {
      // Fallback: just get all assignments and filter
      final assignments = await _client
          .from(_assignmentsTable)
          .select('task_id')
          .eq('volunteer_id', me);
      if ((assignments as List).isEmpty) return 0;
      final taskIds = assignments.map((e) => e['task_id'] as String).toList();
      final tasks = await _client
          .from(_tasksTable)
          .select('id')
          .inFilter('id', taskIds)
          .eq('status', 'completed');
      return (tasks as List).length;
    }
  }

  /// Get pending tasks count for the current volunteer
  Future<int> getMyPendingTasksCount() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return 0;
    try {
      final assignments = await _client
          .from(_assignmentsTable)
          .select('task_id')
          .eq('volunteer_id', me);
      if ((assignments as List).isEmpty) return 0;
      final taskIds = assignments.map((e) => e['task_id'] as String).toList();
      final tasks = await _client
          .from(_tasksTable)
          .select('id')
          .inFilter('id', taskIds)
          .inFilter('status', ['pending', 'active']);
      return (tasks as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Get total volunteer hours (estimate: 2 hours per completed task)
  Future<int> getMyTotalHours() async {
    final completed = await getMyCompletedTasksCount();
    // Estimate 2 hours per completed task
    return completed * 2;
  }

  /// Get tasks that have no volunteers assigned (open to all volunteers).
  /// These are pending/active tasks where task_assignments is empty.
  Future<List<TaskModel>> getOpenTasks() async {
    try {
      // Get all non-completed tasks
      final tasks = await getTasks();
      final nonCompleted = tasks
          .where((t) => t.status != TaskStatus.completed)
          .toList();

      if (nonCompleted.isEmpty) return [];

      // Get task IDs that have assignments
      final assignedTaskIds = <String>{};
      final assignments = await _client
          .from(_assignmentsTable)
          .select('task_id');
      for (final a in (assignments as List)) {
        assignedTaskIds.add((a as Map)['task_id'] as String);
      }

      // Return tasks that have no assignments
      return nonCompleted
          .where((t) => !assignedTaskIds.contains(t.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Tasks currently assigned to the signed-in volunteer. Uses the
  /// `list_my_assigned_tasks` RPC (joins location for display). Falls back to a
  /// direct join in case the RPC is missing.
  Future<List<TaskModel>> getMyAssignedTasks() async {
    try {
      final response = await _client.rpc('list_my_assigned_tasks');
      if (response == null) return [];
      return (response as List)
          .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      final me = _client.auth.currentUser?.id;
      if (me == null) return [];
      final response = await _client
          .from(_assignmentsTable)
          .select('task:tasks(*)')
          .eq('volunteer_id', me);
      return (response as List)
          .map((e) {
            final task = (e as Map)['task'];
            if (task == null) return null;
            return TaskModel.fromJson(Map<String, dynamic>.from(task as Map));
          })
          .whereType<TaskModel>()
          .toList();
    }
  }
}
