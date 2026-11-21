enum ActionType {
  click,
  scroll,
  typeText,
  pressBack,
  pressHome,
  wait,
  done,
  fail
}

class AgentAction {
  final ActionType type;
  final String elementDescription;
  final double x;
  final double y;
  final String text;
  final String direction;
  final String thought;
  final String planCode;

  const AgentAction({
    required this.type,
    this.elementDescription = '',
    this.x = 0,
    this.y = 0,
    this.text = '',
    this.direction = 'down',
    this.thought = '',
    this.planCode = '',
  });

  factory AgentAction.fromPlan(String thought, String planCode) {
    final lower = planCode.toLowerCase();
    if (lower.contains("done")) {
      return AgentAction(type: ActionType.done, thought: thought, planCode: planCode);
    }
    if (lower.contains("fail")) {
      return AgentAction(type: ActionType.fail, thought: thought, planCode: planCode);
    }
    if (lower.contains("click")) {
      final desc = _extractArg(planCode, "element_description") ?? "target element";
      return AgentAction(type: ActionType.click, elementDescription: desc, thought: thought, planCode: planCode);
    }
    if (lower.contains("type")) {
      final txt = _extractArg(planCode, "text") ?? "";
      return AgentAction(type: ActionType.typeText, text: txt, thought: thought, planCode: planCode);
    }
    if (lower.contains("scroll")) {
      final dir = _extractArg(planCode, "direction") ?? "down";
      return AgentAction(type: ActionType.scroll, direction: dir, thought: thought, planCode: planCode);
    }
    return AgentAction(type: ActionType.wait, thought: thought, planCode: planCode);
  }

  static String? _extractArg(String code, String argName) {
    final regex = RegExp('$argName\\s*=\\s*["\']([^"\']+)["\']');
    final match = regex.firstMatch(code);
    return match?.group(1);
  }
}
