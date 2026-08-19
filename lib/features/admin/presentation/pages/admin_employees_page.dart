import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/admin/domain/entities/employee.dart';
import 'package:open_space_parking/features/admin/presentation/providers/admin_providers.dart';

class AdminEmployeesPage extends ConsumerWidget {
  const AdminEmployeesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(adminEmployeesProvider);
    final isCreating = ref.watch(adminLoadingProvider);

    return Stack(
      children: [
        Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: isCreating ? null : () => _showCreateDialog(context, ref),
            icon: const Icon(Icons.person_add),
            label: const Text('Add Employee'),
          ),
          body: employeesAsync.when(
            loading: () => const AppLoadingWidget(message: 'Loading employees...'),
            error: (_, __) => AppErrorWidget(
              message: 'Failed to load employees',
              onRetry: () => ref.invalidate(adminEmployeesProvider),
            ),
            data: (employees) {
              if (employees.isEmpty) {
                return const Center(
                  child: Text('No employees yet. Add your first employee.'),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(adminEmployeesProvider);
                  await ref.read(adminEmployeesProvider.future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final employee = employees[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(employee.fullName.isNotEmpty
                              ? employee.fullName[0].toUpperCase()
                              : 'E'),
                        ),
                        title: Text(employee.fullName),
                        subtitle: Text(employee.phone),
                        onTap: () => context.push(
                          RoutePaths.adminEmployeeDetail(employee.id),
                        ),
                        trailing: Switch(
                          value: employee.isActive,
                          onChanged: isCreating
                              ? null
                              : (value) => _toggleActive(ref, employee, value),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        if (isCreating)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x33000000),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Saving employee...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _toggleActive(
    WidgetRef ref,
    Employee employee,
    bool isActive,
  ) async {
    try {
      await ref.read(adminRepositoryProvider).setEmployeeActive(
            employeeId: employee.id,
            isActive: isActive,
          );
      ref.invalidate(adminEmployeesProvider);
      ref.invalidate(activeEmployeesProvider);
      ref.invalidate(adminStatisticsProvider);
      ref.read(snackbarServiceProvider).showSuccess(
            isActive ? 'Employee activated' : 'Employee deactivated',
          );
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Could not update employee.');
    }
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Employee'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: nameController,
                  label: 'Employee Name',
                  validator: (v) =>
                      Validators.requiredField(v, fieldName: 'Employee name'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: phoneController,
                  label: 'Mobile Number',
                  keyboardType: TextInputType.phone,
                  validator: Validators.mobileNumber,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (created != true) return;

    final loading = ref.read(adminLoadingProvider.notifier);
    loading.state = true;
    try {
      final result = await ref.read(adminRepositoryProvider).createEmployee(
            fullName: nameController.text,
            phone: phoneController.text,
          );
      ref.invalidate(adminEmployeesProvider);
      ref.invalidate(activeEmployeesProvider);
      ref.invalidate(adminStatisticsProvider);
      await ref.read(adminEmployeesProvider.future);

      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Employee Created'),
          content: Text(
            '${result.employee.fullName} was added successfully.\n\n'
            'Share these login details with the employee:\n'
            'Open the app → Sign in with phone number\n'
            'Mobile: ${result.employee.phone}\n'
            'Password: ${result.temporaryPassword}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Could not create employee.');
    } finally {
      loading.state = false;
    }
  }
}
