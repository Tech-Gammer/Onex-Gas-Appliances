// import 'package:flutter/material.dart';
//
// class NEWSPAGE extends StatefulWidget {
//   const NEWSPAGE({super.key});
//
//   @override
//   State<NEWSPAGE> createState() => _NEWSPAGEState();
// }
//
// class _NEWSPAGEState extends State<NEWSPAGE> {
//
//
//   Future<void> savePurchase() async {
//     if (!mounted) return;
//
//     final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//
//     if (_formKey.currentState!.validate()) {
//       if (_selectedVendor == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(languageProvider.isEnglish
//               ? 'Please select a vendor'
//               : 'براہ کرم فروش منتخب کریں')),
//         );
//         return;
//       }
//
//       // Get only items that have been filled
//       List<PurchaseItem> validItems = _purchaseItems.where((purchaseItem) =>
//       purchaseItem.itemNameController.text.isNotEmpty &&
//           purchaseItem.quantityController.text.isNotEmpty &&
//           purchaseItem.priceController.text.isNotEmpty
//       ).toList();
//
//       if (validItems.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(languageProvider.isEnglish
//               ? 'Please add at least one item'
//               : 'براہ کرم کم از کم ایک آئٹم شامل کریں')),
//         );
//         return;
//       }
//
//       try {
//         final database = FirebaseDatabase.instance.ref();
//         String vendorKey = _selectedVendor!['key'];
//
//         // Create a single purchase record with all valid items
//         final newPurchase = {
//           'items': validItems.map((purchaseItem) => {
//             'itemName': purchaseItem.itemNameController.text,
//             'quantity': double.tryParse(purchaseItem.quantityController.text) ?? 0.0,
//             'purchasePrice': double.tryParse(purchaseItem.priceController.text) ?? 0.0,
//             'total': (double.tryParse(purchaseItem.quantityController.text) ?? 0.0) *
//                 (double.tryParse(purchaseItem.priceController.text) ?? 0.0),
//             'isBOM': _items.any((item) =>
//             item['itemName'].toLowerCase() == purchaseItem.itemNameController.text.toLowerCase() &&
//                 item['isBOM'] == true),
//           }).toList(),
//           'vendorId': vendorKey,
//           'vendorName': _selectedVendor!['name'],
//           'grandTotal': calculateTotal(),
//           'timestamp': _selectedDateTime.toString(),
//           'type': 'credit',
//           'hasBOM': validItems.any((purchaseItem) =>
//               _items.any((inventoryItem) =>
//               inventoryItem['itemName'].toLowerCase() ==
//                   purchaseItem.itemNameController.text.toLowerCase() &&
//                   inventoryItem['isBOM'] == true
//               )
//           ),
//         };
//
//         // Save the purchase and get the key
//         final purchaseRef = database.child('purchases').push();
//         final purchaseId = purchaseRef.key;
//         await purchaseRef.set(newPurchase);
//
//         // Track component consumption
//         final componentConsumptionRef = database.child('componentConsumption').child(purchaseId!);
//
//         // First pass: Update all items (both regular and BOM)
//         for (var purchaseItem in validItems) {
//           String itemName = purchaseItem.itemNameController.text;
//           double purchasedQty = double.tryParse(purchaseItem.quantityController.text) ?? 0.0;
//           double purchasePrice = double.tryParse(purchaseItem.priceController.text) ?? 0.0;
//
//           // Find the item in inventory
//           var existingItem = _items.firstWhere(
//                 (inventoryItem) =>
//             inventoryItem['itemName'].toLowerCase() == itemName.toLowerCase(),
//             orElse: () => {},
//           );
//
//           if (existingItem.isNotEmpty) {
//             String itemKey = existingItem['key'];
//             double currentQty = existingItem['qtyOnHand']?.toDouble() ?? 0.0;
//
//             // Update quantity and price for ALL items (including BOM)
//             await database.child('items').child(itemKey).update({
//               'qtyOnHand': currentQty + purchasedQty,
//               'costPrice': purchasePrice,
//             });
//
//             // If this is a BOM item, process its components
//             if (existingItem['isBOM'] == true) {
//               Map<String, dynamic> components = existingItem['components'] ?? {};
//
//               // Record component consumption for this BOM item
//               Map<String, dynamic> consumptionRecord = {
//                 'bomItemName': itemName,
//                 'bomItemKey': itemKey,
//                 'quantityProduced': purchasedQty,
//                 'timestamp': _selectedDateTime.toString(),
//                 'components': {},
//               };
//
//               // Deduct components from inventory
//               for (var componentEntry in components.entries) {
//                 String componentName = componentEntry.key;
//                 double componentQtyPerUnit = (componentEntry.value as num).toDouble();
//                 double totalComponentQty = componentQtyPerUnit * purchasedQty;
//
//                 // Find component in inventory
//                 var componentItem = _items.firstWhere(
//                       (item) => item['itemName'].toLowerCase() == componentName.toLowerCase(),
//                   orElse: () => {},
//                 );
//
//                 if (componentItem.isNotEmpty) {
//                   String componentKey = componentItem['key'];
//                   double currentComponentQty = componentItem['qtyOnHand']?.toDouble() ?? 0.0;
//
//                   // Check if we have enough components
//                   if (currentComponentQty >= totalComponentQty) {
//                     // Deduct the components
//                     await database.child('items').child(componentKey).update({
//                       'qtyOnHand': currentComponentQty - totalComponentQty,
//                     });
//
//                     // Record successful consumption
//                     consumptionRecord['components'][componentName] = {
//                       'quantityUsed': totalComponentQty,
//                       'remaining': currentComponentQty - totalComponentQty,
//                     };
//                   } else {
//                     // Record partial consumption (if any) and wastage
//                     double actualUsed = currentComponentQty;
//                     await database.child('items').child(componentKey).update({
//                       'qtyOnHand': 0.0,
//                     });
//
//                     consumptionRecord['components'][componentName] = {
//                       'quantityUsed': actualUsed,
//                       'remaining': 0.0,
//                       'shortage': totalComponentQty - actualUsed,
//                     };
//
//                     // Record wastage
//                     await database.child('wastage').push().set({
//                       'itemName': componentName,
//                       'quantity': totalComponentQty - actualUsed,
//                       'date': DateTime.now().toString(),
//                       'purchaseId': purchaseId,
//                       'type': 'component_shortage',
//                       'relatedBOM': itemName,
//                     });
//                   }
//                 }
//               }
//
//               // Save the consumption record
//               await componentConsumptionRef.set(consumptionRecord);
//             }
//           }
//         }
//
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text(languageProvider.isEnglish
//                 ? 'Purchase recorded successfully!'
//                 : 'خریداری کامیابی سے ریکارڈ ہو گئی!')),
//           );
//
//           // Clear form after successful save
//           _clearForm();
//         }
//       } catch (error) {
//         print('Purchase error: $error');
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text(languageProvider.isEnglish
//                 ? 'Failed to record purchase: ${error.toString()}'
//                 : 'خریداری ریکارڈ کرنے میں ناکامی: ${error.toString()}')),
//           );
//         }
//       }
//     }
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//
//     );
//   }
// }
