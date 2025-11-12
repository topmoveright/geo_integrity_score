import 'package:flutter/material.dart';

import '../formatters.dart';
import '../example_data.dart';

class LogSection extends StatelessWidget {
  const LogSection({required this.logs, super.key});

  final List<ScenarioLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Execution Log',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: logs.isEmpty
              ? const Center(child: Text('No scenarios executed.'))
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (BuildContext context, int index) {
                    final ScenarioLogEntry entry = logs[index];
                    final String typeLabel = entry.monitoringStarted
                        ? 'Monitoring'
                        : (entry.error != null ? 'Error' : 'Detection');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '[${formatLocalTimestamp(entry.timestamp)}] $typeLabel',
                          ),
                          if (entry.detection != null)
                            Text(
                              'Fraud ${entry.detection!.fraudScore} | '
                              '${entry.detection!.platform} | ${entry.label}',
                            )
                          else
                            Text(entry.label),
                          if (entry.error != null)
                            Text('Error: ${entry.error}'),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
