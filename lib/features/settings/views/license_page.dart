import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class LicensePage extends StatelessWidget {
  const LicensePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsLicense)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _licenseText,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  static const _licenseText = '''MyAnime - Copyright (C) 2026 yuanzhe

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.

---

GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.

The full license text is available at:
https://www.gnu.org/licenses/gpl-3.0.html

Key points:
- You may use, copy, modify, and distribute this software.
- Any distributed or modified version must also be released under
  GPLv3 with source code available.
- You may NOT incorporate this software into proprietary programs.
- There is NO WARRANTY for this software.''';
}
