// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../models/event.dart';
// import '../providers/event_provider.dart';
// import '../../map/widgets/location_search_dialog.dart';
// import '../data/event_repository.dart';

// class EventDialog extends ConsumerStatefulWidget {
//   final DateTime initialDate;
//   final Event? event;

//   const EventDialog({super.key, required this.initialDate, this.event});

//   @override
//   ConsumerState<EventDialog> createState() => _EventDialogState();
// }

// class _EventDialogState extends ConsumerState<EventDialog> {
//   final _titleController = TextEditingController();
//   final _contentController = TextEditingController();
//   final _locationController = TextEditingController();
//   bool _isAllDay = true;
//   int? _alarmMinutesBefore;
//   DateTime? _startDate;
//   DateTime? _endDate;
//   TimeOfDay? _startTime;
//   TimeOfDay? _endTime;
//   int? _selectedTagId;
//   double? _locationLat;
//   double? _locationLng;

//   @override
//   void initState() {
//     super.initState();
//     if (widget.event != null) {
//       final e = widget.event!;
//       _titleController.text = e.title;
//       _contentController.text = e.content ?? '';
//       _locationController.text = e.locationName ?? '';
//       _locationLat = e.locationLat;
//       _locationLng = e.locationLng;
//       _isAllDay = e.isAllDay;
//       if (e.alarmEnabled) {
//         _alarmMinutesBefore = e.alarmDaysBefore > 0 ? e.alarmDaysBefore : 30;
//       }
//       _startDate = e.startDate != null
//           ? DateTime.parse(e.startDate!)
//           : widget.initialDate;
//       _endDate = e.endDate != null
//           ? DateTime.parse(e.endDate!)
//           : widget.initialDate;
//       if (e.startTime != null) {
//         final parts = e.startTime!.split(':');
//         _startTime = TimeOfDay(
//           hour: int.parse(parts[0]),
//           minute: int.parse(parts[1]),
//         );
//       }
//       if (e.endTime != null) {
//         final parts = e.endTime!.split(':');
//         _endTime = TimeOfDay(
//           hour: int.parse(parts[0]),
//           minute: int.parse(parts[1]),
//         );
//       }
//     } else {
//       _startDate = widget.initialDate;
//       _endDate = widget.initialDate;
//     }

//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       if (widget.event?.id != null) {
//         final repo = ref.read(eventRepositoryProvider);
//         final tags = await repo.getEventTags(widget.event!.id!);
//         setState(() => _selectedTagId = tags.isNotEmpty ? tags.first.id : null);
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _titleController.dispose();
//     _contentController.dispose();
//     _locationController.dispose();
//     super.dispose();
//   }

//   String _formatDate(DateTime date) =>
//       '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

//   Future<void> _pickDate(bool isStart) async {
//     final initial = isStart
//         ? (_startDate ?? widget.initialDate)
//         : (_endDate ?? widget.initialDate);
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: initial,
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2100),
//     );
//     if (picked == null) return;
//     setState(() {
//       if (isStart) {
//         _startDate = picked;
//         if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
//       } else {
//         _endDate = picked;
//       }
//     });
//   }

//   Future<void> _pickTime(bool isStart) async {
//     final picked = await showTimePicker(
//       context: context,
//       initialTime: isStart
//           ? (_startTime ?? TimeOfDay.now())
//           : (_endTime ?? TimeOfDay.now()),
//     );
//     if (picked == null) return;
//     setState(() {
//       if (isStart)
//         _startTime = picked;
//       else
//         _endTime = picked;
//     });
//   }

//   Future<void> _pickLocation() async {
//     final result = await showDialog<LocationSearchResult>(
//       context: context,
//       builder: (context) => const LocationSearchDialog(),
//     );
//     if (result == null) return;
//     setState(() {
//       _locationController.text = result.name;
//       _locationLat = result.lat;
//       _locationLng = result.lng;
//     });
//   }

//   Future<void> _save() async {
//     if (_titleController.text.isEmpty) return;

//     final startDateStr = _formatDate(_startDate ?? widget.initialDate);
//     final endDateStr = _formatDate(_endDate ?? widget.initialDate);

//     final event = Event(
//       id: widget.event?.id,
//       title: _titleController.text,
//       createdAt: widget.event?.createdAt ?? DateTime.now().toIso8601String(),
//       alarmEnabled: _alarmMinutesBefore != null,
//       alarmDaysBefore: _alarmMinutesBefore ?? 0,
//       alarmTime: '09:00',
//       isAllDay: _isAllDay,
//       eventDate: startDateStr,
//       startDate: startDateStr,
//       endDate: endDateStr,
//       startTime: _isAllDay
//           ? null
//           : _startTime != null
//           ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
//           : null,
//       endTime: _isAllDay
//           ? null
//           : _endTime != null
//           ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
//           : null,
//       content: _contentController.text.isEmpty ? null : _contentController.text,
//       locationName: _locationController.text.isEmpty
//           ? null
//           : _locationController.text,
//       locationLat: _locationLat,
//       locationLng: _locationLng,
//       googleEventId: widget.event?.googleEventId,
//       priority: widget.event?.priority ?? 1,
//       isCompleted: widget.event?.isCompleted ?? false,
//       tagColor: widget.event?.tagColor,
//     );

//     final notifier = ref.read(eventListProvider.notifier);
//     int? savedId;
//     if (widget.event != null) {
//       await notifier.updateEvent(event);
//       savedId = widget.event!.id;
//     } else {
//       savedId = await notifier.addEvent(event);
//     }

//     if (savedId != null) {
//       final repo = ref.read(eventRepositoryProvider);
//       await repo.setEventTags(
//         savedId,
//         _selectedTagId != null ? [_selectedTagId!] : [],
//       );
//     }

//     if (mounted) Navigator.pop(context);
//   }

//   Color _hexToColor(String hex) {
//     try {
//       return Color(int.parse(hex.replaceFirst('#', '0xFF')));
//     } catch (_) {
//       return const Color(0xFF4A90E2);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final tagsAsync = ref.watch(eventTagProvider);

//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: SizedBox(
//         width: 480,
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // 제목
//               Text(
//                 widget.event != null ? '일정 편집' : '일정 추가',
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 20),

//               // 제목 입력
//               TextField(
//                 controller: _titleController,
//                 autofocus: true,
//                 decoration: InputDecoration(
//                   hintText: '제목',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   isDense: true,
//                 ),
//               ),
//               const SizedBox(height: 12),

//               // 하루종일
//               Row(
//                 children: [
//                   const Text('하루종일', style: TextStyle(fontSize: 13)),
//                   const Spacer(),
//                   Switch(
//                     value: _isAllDay,
//                     onChanged: (v) => setState(() => _isAllDay = v),
//                   ),
//                 ],
//               ),

//               // 일시
//               Row(
//                 children: [
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           '시작',
//                           style: TextStyle(fontSize: 11, color: Colors.grey),
//                         ),
//                         const SizedBox(height: 4),
//                         MouseRegion(
//                           cursor: SystemMouseCursors.click,
//                           child: GestureDetector(
//                             onTap: () => _pickDate(true),
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 8,
//                                 vertical: 6,
//                               ),
//                               decoration: BoxDecoration(
//                                 border: Border.all(
//                                   color: const Color(0xFFDDDDDD),
//                                 ),
//                                 borderRadius: BorderRadius.circular(6),
//                               ),
//                               child: Text(
//                                 _formatDate(_startDate ?? widget.initialDate),
//                                 style: const TextStyle(fontSize: 12),
//                               ),
//                             ),
//                           ),
//                         ),
//                         if (!_isAllDay) ...[
//                           const SizedBox(height: 4),
//                           MouseRegion(
//                             cursor: SystemMouseCursors.click,
//                             child: GestureDetector(
//                               onTap: () => _pickTime(true),
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 8,
//                                   vertical: 6,
//                                 ),
//                                 decoration: BoxDecoration(
//                                   border: Border.all(
//                                     color: const Color(0xFFDDDDDD),
//                                   ),
//                                   borderRadius: BorderRadius.circular(6),
//                                 ),
//                                 child: Text(
//                                   _startTime != null
//                                       ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
//                                       : '시간 선택',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: _startTime == null
//                                         ? Colors.grey
//                                         : null,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ],
//                     ),
//                   ),
//                   const Padding(
//                     padding: EdgeInsets.symmetric(horizontal: 8),
//                     child: Text('~', style: TextStyle(color: Colors.grey)),
//                   ),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           '종료',
//                           style: TextStyle(fontSize: 11, color: Colors.grey),
//                         ),
//                         const SizedBox(height: 4),
//                         MouseRegion(
//                           cursor: SystemMouseCursors.click,
//                           child: GestureDetector(
//                             onTap: () => _pickDate(false),
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 8,
//                                 vertical: 6,
//                               ),
//                               decoration: BoxDecoration(
//                                 border: Border.all(
//                                   color: const Color(0xFFDDDDDD),
//                                 ),
//                                 borderRadius: BorderRadius.circular(6),
//                               ),
//                               child: Text(
//                                 _formatDate(_endDate ?? widget.initialDate),
//                                 style: const TextStyle(fontSize: 12),
//                               ),
//                             ),
//                           ),
//                         ),
//                         if (!_isAllDay) ...[
//                           const SizedBox(height: 4),
//                           MouseRegion(
//                             cursor: SystemMouseCursors.click,
//                             child: GestureDetector(
//                               onTap: () => _pickTime(false),
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 8,
//                                   vertical: 6,
//                                 ),
//                                 decoration: BoxDecoration(
//                                   border: Border.all(
//                                     color: const Color(0xFFDDDDDD),
//                                   ),
//                                   borderRadius: BorderRadius.circular(6),
//                                 ),
//                                 child: Text(
//                                   _endTime != null
//                                       ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
//                                       : '시간 선택',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: _endTime == null
//                                         ? Colors.grey
//                                         : null,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),

//               // 장소
//               TextField(
//                 controller: _locationController,
//                 readOnly: true,
//                 decoration: InputDecoration(
//                   hintText: '장소',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   isDense: true,
//                   prefixIcon: const Icon(Icons.location_on, size: 16),
//                   suffixIcon: _locationController.text.isNotEmpty
//                       ? IconButton(
//                           icon: const Icon(Icons.close, size: 16),
//                           onPressed: () => setState(() {
//                             _locationController.clear();
//                             _locationLat = null;
//                             _locationLng = null;
//                           }),
//                         )
//                       : null,
//                 ),
//                 onTap: _pickLocation,
//               ),
//               const SizedBox(height: 12),

//               // 태그
//               const Text(
//                 '태그',
//                 style: TextStyle(fontSize: 11, color: Colors.grey),
//               ),
//               const SizedBox(height: 6),
//               tagsAsync.when(
//                 loading: () => const SizedBox(),
//                 error: (e, _) => const SizedBox(),
//                 data: (tags) => tags.isEmpty
//                     ? const Text(
//                         '태그 없음',
//                         style: TextStyle(fontSize: 11, color: Colors.grey),
//                       )
//                     : Wrap(
//                         spacing: 6,
//                         runSpacing: 6,
//                         children: tags.map((tag) {
//                           final isSelected = _selectedTagId == tag.id;
//                           final color = _hexToColor(tag.color);
//                           return GestureDetector(
//                             onTap: () => setState(() {
//                               _selectedTagId = isSelected ? null : tag.id;
//                             }),
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 10,
//                                 vertical: 4,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: isSelected
//                                     ? color
//                                     : color.withOpacity(0.15),
//                                 borderRadius: BorderRadius.circular(12),
//                                 border: Border.all(color: color),
//                               ),
//                               child: Text(
//                                 tag.name,
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: isSelected ? Colors.white : color,
//                                 ),
//                               ),
//                             ),
//                           );
//                         }).toList(),
//                       ),
//               ),
//               const SizedBox(height: 12),

//               // 내용
//               TextField(
//                 controller: _contentController,
//                 maxLines: 3,
//                 decoration: InputDecoration(
//                   hintText: '내용',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   isDense: true,
//                 ),
//               ),
//               const SizedBox(height: 12),

//               // 알림
//               Row(
//                 children: [
//                   const Text('알림', style: TextStyle(fontSize: 13)),
//                   const Spacer(),
//                   Switch(
//                     value: _alarmMinutesBefore != null,
//                     onChanged: (v) => setState(() {
//                       _alarmMinutesBefore = v ? 30 : null;
//                     }),
//                   ),
//                 ],
//               ),
//               if (_alarmMinutesBefore != null) ...[
//                 const SizedBox(height: 8),
//                 DropdownButton<int>(
//                   value: _alarmMinutesBefore,
//                   isDense: true,
//                   items: const [
//                     DropdownMenuItem(value: 5, child: Text('5분 전')),
//                     DropdownMenuItem(value: 10, child: Text('10분 전')),
//                     DropdownMenuItem(value: 30, child: Text('30분 전')),
//                     DropdownMenuItem(value: 60, child: Text('1시간 전')),
//                     DropdownMenuItem(value: 120, child: Text('2시간 전')),
//                     DropdownMenuItem(value: 1440, child: Text('1일 전')),
//                   ],
//                   onChanged: (v) => setState(() => _alarmMinutesBefore = v),
//                 ),
//               ],
//               const SizedBox(height: 20),

//               // 버튼
//               Row(
//                 children: [
//                   if (widget.event != null)
//                     TextButton.icon(
//                       onPressed: () {
//                         ref
//                             .read(eventListProvider.notifier)
//                             .deleteEvent(widget.event!.id!);
//                         Navigator.pop(context);
//                       },
//                       icon: const Icon(
//                         Icons.delete,
//                         size: 16,
//                         color: Colors.red,
//                       ),
//                       label: const Text(
//                         '삭제',
//                         style: TextStyle(color: Colors.red),
//                       ),
//                     ),
//                   const Spacer(),
//                   OutlinedButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: const Text('취소'),
//                   ),
//                   const SizedBox(width: 8),
//                   ElevatedButton(
//                     onPressed: _save,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: const Color(0xFF4A90E2),
//                       foregroundColor: Colors.white,
//                     ),
//                     child: const Text('저장'),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
