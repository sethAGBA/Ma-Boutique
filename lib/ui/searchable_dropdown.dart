import 'package:flutter/material.dart';

/// Représente un élément sélectionnable dans le dropdown avec recherche.
class SearchableItem<T> {
  final T value;
  final String titre;
  final String? sousTitre;
  final String? reference;
  final Widget? trailing;
  final IconData? icone;
  final Color? iconeCouleur;
  final Color? iconeBg;

  const SearchableItem({
    required this.value,
    required this.titre,
    this.sousTitre,
    this.reference,
    this.trailing,
    this.icone,
    this.iconeCouleur,
    this.iconeBg,
  });

  /// Recherche textuelle insensible à la casse et aux espaces
  bool correspond(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().trim();
    if (titre.toLowerCase().contains(q)) return true;
    if (sousTitre != null && sousTitre!.toLowerCase().contains(q)) return true;
    if (reference != null && reference!.toLowerCase().contains(q)) return true;
    return false;
  }
}

/// Dropdown avec champ de recherche en temps réel, filtre instantané et validation de formulaire.
class SearchableDropdown<T> extends FormField<T> {
  final T? value;
  final List<SearchableItem<T>> items;
  final String label;
  final String hint;
  final String titreDialogue;
  final IconData? prefixIcon;
  final ValueChanged<T?>? onChanged;
  final bool permetEffacer;
  final String texteEffacer;

  SearchableDropdown({
    super.key,
    this.value,
    required this.items,
    required this.label,
    this.hint = 'Rechercher ou sélectionner...',
    this.titreDialogue = 'Sélectionner un élément',
    this.prefixIcon,
    this.onChanged,
    this.permetEffacer = false,
    this.texteEffacer = 'Aucun (désélectionner)',
    super.validator,
  }) : super(
          initialValue: value,
          builder: (FormFieldState<T> state) {
            SearchableItem<T>? itemSelectionne;
            try {
              itemSelectionne = items.firstWhere((i) => i.value == state.value);
            } catch (_) {
              itemSelectionne = null;
            }

            final context = state.context;
            final theme = Theme.of(context);
            final aErreur = state.hasError;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final resultat = await showDialog<T?>(
                      context: context,
                      builder: (ctx) => _SearchDialog<T>(
                        items: items,
                        titreDialogue: titreDialogue,
                        valeurActuelle: state.value,
                        permetEffacer: permetEffacer,
                        texteEffacer: texteEffacer,
                      ),
                    );

                    // Si l'utilisateur a cliqué sur un élément (ou sur effacer avec null)
                    if (resultat != null || permetEffacer) {
                      state.didChange(resultat);
                      onChanged?.call(resultat);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: label,
                      hintText: hint,
                      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (permetEffacer && state.value != null)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              tooltip: 'Effacer la sélection',
                              onPressed: () {
                                state.didChange(null);
                                onChanged?.call(null);
                              },
                            ),
                          const Icon(Icons.arrow_drop_down_rounded, size: 28),
                          const SizedBox(width: 6),
                        ],
                      ),
                      errorText: aErreur ? state.errorText : null,
                    ),
                    isEmpty: itemSelectionne == null,
                    child: itemSelectionne != null
                        ? Text(
                            itemSelectionne.titre,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : Text(
                            hint,
                            style: TextStyle(fontSize: 14, color: theme.hintColor),
                          ),
                  ),
                ),
              ],
            );
          },
        );
}

class _SearchDialog<T> extends StatefulWidget {
  final List<SearchableItem<T>> items;
  final String titreDialogue;
  final T? valeurActuelle;
  final bool permetEffacer;
  final String texteEffacer;

  const _SearchDialog({
    required this.items,
    required this.titreDialogue,
    this.valeurActuelle,
    required this.permetEffacer,
    required this.texteEffacer,
  });

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  final TextEditingController _ctrl = TextEditingController();
  String _recherche = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtres = widget.items.where((item) => item.correspond(_recherche)).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Entête
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.titreDialogue,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${filtres.length} élément(s) disponible(s)',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Champ de recherche avec filtre en direct
              TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Rechercher un élément',
                  hintText: 'Tapez un nom, référence, téléphone...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _recherche.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _recherche = '');
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                onChanged: (q) => setState(() => _recherche = q),
              ),
              const SizedBox(height: 12),

              // Option pour effacer la sélection (si permise)
              if (widget.permetEffacer && _recherche.isEmpty) ...[
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  leading: const Icon(Icons.block_rounded, size: 20, color: Color(0xFF94A3B8)),
                  title: Text(widget.texteEffacer, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  onTap: () => Navigator.pop(context, null),
                ),
                const Divider(height: 8),
              ],

              // Liste des résultats
              Expanded(
                child: filtres.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: const Icon(Icons.search_off_rounded, size: 28, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Aucun résultat pour « $_recherche »',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Vérifiez l’orthographe ou essayez un mot plus court.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtres.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 48),
                        itemBuilder: (context, i) {
                          final item = filtres[i];
                          final estSelectionne = item.value == widget.valeurActuelle;

                          return ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            selected: estSelectionne,
                            selectedTileColor: const Color(0xFFDCFCE7).withValues(alpha: 0.5),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: item.iconeBg ?? (estSelectionne ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                item.icone ?? Icons.label_outline_rounded,
                                size: 18,
                                color: item.iconeCouleur ?? (estSelectionne ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                              ),
                            ),
                            title: Text(
                              item.titre,
                              style: TextStyle(
                                fontWeight: estSelectionne ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 13,
                                color: estSelectionne ? theme.colorScheme.primary : const Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: item.sousTitre != null
                                ? Text(
                                    item.sousTitre!,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.trailing != null) item.trailing!,
                                if (estSelectionne) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF16A34A)),
                                ],
                              ],
                            ),
                            onTap: () => Navigator.pop(context, item.value),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 8),

              // Bouton Annuler
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
