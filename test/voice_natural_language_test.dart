import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/models/voice_task_draft.dart';
import 'package:momentum/services/voice_task_parser.dart';

void main() {
  final parser = VoiceTaskParser();
  final now = DateTime(2026, 10, 28, 14, 20);
  VoiceTaskDraft parse(String input) => parser.parse(input, now: now).single;

  test('conversational English keeps the action in the task name', () {
    final task = parse(
        'Can you please remind me to finish the report tomorrow at six thirty p.m. for half an hour?');
    expect(task.action, VoiceTaskAction.add);
    expect(task.title, 'finish the report');
    expect(task.date, DateTime(2026, 10, 29));
    expect(task.hour, 18);
    expect(task.minute, 30);
    expect(task.minutes, 30);
    expect(parse('I need to finish the report').action, VoiceTaskAction.add);
    expect(
        parse('Remind me tomorrow at six p.m to call Mum').title, 'call Mum');
    expect(parse('Add read at 6 P M').hour, 18);
  });

  test('Hindi and romanized Hindi conversational titles stay intact', () {
    final task = parse('मुझे कल शाम छह बजे दूध खरीदना है');
    expect(task.title, 'दूध खरीदना');
    expect(task.date, DateTime(2026, 10, 29));
    expect(task.hour, 18);
    final mixed = parse('mujhe kal shaam chhe baje Python padhna hai');
    expect(mixed.title, 'Python padhna');
    expect(mixed.hour, 18);
    expect(parse('कल सुबह सात बजे योग आधा घंटा जोड़ो').minutes, 30);
  });

  test('Chrono extracts weekdays, named dates and relative days offline', () {
    final friday = parse('Remind me to call Mum next Friday at five pm');
    expect(friday.title, 'call Mum');
    // Chrono interprets "next Friday" as Friday in the following week.
    expect(friday.date, DateTime(2026, 11, 6));
    expect(friday.hour, 17);
    expect(
        parse('Add renew passport on November 5').date, DateTime(2026, 11, 5));
    expect(parse('Add renew passport on 5 November').title, 'renew passport');
    expect(parse('Add read in three days').date, DateTime(2026, 10, 31));
    expect(parse('सोमवार को किताब पढ़ना जोड़ो').title, 'किताब पढ़ना');
    expect(parse('सोमवार को किताब पढ़ना जोड़ो').date, DateTime(2026, 11, 2));
    expect(parse('तीन दिन बाद किताब पढ़ना जोड़ो').date, DateTime(2026, 10, 31));
    expect(parse('Add prepare notes next week').date, DateTime(2026, 11, 4));
  });

  test('start delays are distinct from task durations', () {
    final task = parse('Remind me to call Mum in ten minutes for five minutes');
    expect(task.title, 'call Mum');
    expect(task.date, DateTime(2026, 10, 28));
    expect(task.hour, 14);
    expect(task.minute, 30);
    expect(task.minutes, 5);
    final overnight = parser
        .parse('Add call Mum in ten minutes',
            now: DateTime(2026, 12, 31, 23, 55))
        .single;
    expect(overnight.date, DateTime(2027, 1, 1));
    expect(overnight.hour, 0);
    expect(overnight.minute, 5);
  });

  test('compound duration and natural clock language leave clean titles', () {
    final task = parse(
        'I want to study Python tomorrow at six in the evening for one hour and thirty minutes');
    expect(task.title, 'study Python');
    expect(task.hour, 18);
    expect(task.minutes, 90);
    expect(parse('Add read for one and a half hours').minutes, 90);
    expect(parse('Add read for a quarter of an hour').minutes, 15);
  });

  test('names and ordinary numbers are not guessed as dates or times', () {
    final task = parse('Remind me to call May about chapter 6');
    expect(task.title, 'call May about chapter 6');
    expect(task.date, isNull);
    expect(task.hour, isNull);
  });

  test('conflicting schedules and unclear times require correction', () {
    for (final command in [
      'Add read tomorrow today',
      'Add read tomorrow Friday',
      'Add read Monday to Friday',
      'Add read 2026-11-01 2026-11-02',
      'Add read at 5 pm at 6 pm',
      'Add read at six',
      'Add read tomorrow in ten minutes',
      'Add read in ten minutes at 6 pm',
      'Add read in 25 hours',
      'Add read in one hundred minutes',
      'Add read in one hour and thirty minutes',
      'Add read on November 31',
      'Add read for ten minutes or twenty minutes',
      'Add read for ten minutes for twenty minutes',
      'kal task complete mat karo',
    ]) {
      expect(() => parse(command), throwsFormatException, reason: command);
    }
  });

  test('bare weekdays always resolve to that weekday across the week', () {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    for (var day = 26; day <= 32; day++) {
      final reference = DateTime(2026, 10, day, 23);
      for (var index = 0; index < weekdays.length; index++) {
        final task = parser
            .parse('Add call Mum on ${weekdays[index]}', now: reference)
            .single;
        final offset = (index + 1 - reference.weekday + 7) % 7;
        expect(task.date,
            DateTime(reference.year, reference.month, reference.day + offset),
            reason: '${weekdays[index]} from $reference');
      }
    }
  });
}
