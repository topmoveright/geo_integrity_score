import 'package:flutter/material.dart';

import '../example_data.dart';
import 'compact_button_style.dart';

class ScenarioSection extends StatelessWidget {
  const ScenarioSection({
    required this.scenarios,
    required this.selectedEnvironment,
    required this.permissionGranted,
    required this.scenarioInProgress,
    required this.onRunScenario,
    super.key,
  });

  final List<ExampleScenario> scenarios;
  final TestEnvironment selectedEnvironment;
  final bool permissionGranted;
  final bool scenarioInProgress;
  final ValueChanged<ExampleScenario> onRunScenario;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle buttonStyle = compactButtonStyle();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Scenarios', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            itemCount: scenarios.length,
            itemBuilder: (BuildContext context, int index) {
              final ExampleScenario scenario = scenarios[index];
              final bool recommended = scenario.recommendedEnvironments
                  .contains(selectedEnvironment);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: Text(scenario.name)),
                        TextButton(
                          style: buttonStyle,
                          onPressed: (!permissionGranted || scenarioInProgress)
                              ? null
                              : () => onRunScenario(scenario),
                          child: Text(
                            scenario.usesMonitoring ? 'Monitor' : 'Detect',
                          ),
                        ),
                      ],
                    ),
                    Text(
                      scenario.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (recommended)
                      Text('Recommended on ${selectedEnvironment.label}'),
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
