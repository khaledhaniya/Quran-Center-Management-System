import 'package:flutter/material.dart';
import '../utils/registration_rules.dart';

class WhatsAppNumberField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  const WhatsAppNumberField(
      {super.key, required this.controller, required this.label});
  @override
  State<WhatsAppNumberField> createState() => _WhatsAppNumberFieldState();
}

class _WhatsAppNumberFieldState extends State<WhatsAppNumberField> {
  late final TextEditingController _number;
  late String _code;
  @override
  void initState() {
    super.initState();
    final parts = RegistrationRules.splitWhatsApp(widget.controller.text);
    _code = parts.code;
    _number = TextEditingController(text: parts.number);
  }

  void _update() {
    var national = _number.text;
    if (national.startsWith('0')) national = national.substring(1);
    widget.controller.text = national.isEmpty ? '' : '$_code$national';
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 94,
              child: DropdownButtonFormField<String>(
                initialValue: _code,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'المقدمة',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    border: OutlineInputBorder()),
                items: const ['+970', '+972']
                    .map((code) =>
                        DropdownMenuItem(value: code, child: Text(code)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _code = value);
                    _update();
                  }
                },
              )),
          const SizedBox(width: 8),
          Expanded(
              child: TextFormField(
            controller: _number,
            keyboardType: TextInputType.phone,
            inputFormatters: const [LimitedDigitsFormatter(10)],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) => RegistrationRules.whatsAppError(value),
            onChanged: (_) => _update(),
            decoration: InputDecoration(
                labelText: widget.label,
                hintText: '59xxxxxxx',
                errorMaxLines: 2,
                isDense: true,
                border: const OutlineInputBorder()),
          )),
        ]),
      );
}
