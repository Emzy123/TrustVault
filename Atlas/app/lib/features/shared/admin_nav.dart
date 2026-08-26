import 'package:flutter/material.dart';

class AdminNavItem {
  const AdminNavItem(this.label, this.icon, this.selectedIcon, this.path);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}

const adminNavItems = [
  AdminNavItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard, '/admin'),
  AdminNavItem('KYC Review', Icons.how_to_reg_outlined, Icons.how_to_reg, '/admin/kyc'),
  AdminNavItem('Funding Queue', Icons.pending_actions_outlined, Icons.pending_actions, '/admin/funding'),
  AdminNavItem('Withdrawals', Icons.outbound_outlined, Icons.outbound, '/admin/withdrawals'),
  AdminNavItem('Transactions', Icons.receipt_long_outlined, Icons.receipt_long, '/admin/transactions'),
  AdminNavItem('Flags Queue', Icons.flag_outlined, Icons.flag, '/admin/flags'),
];

const superAdminNavItems = [
  AdminNavItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard, '/superadmin'),
  AdminNavItem('KYC Review', Icons.how_to_reg_outlined, Icons.how_to_reg, '/superadmin/kyc'),
  AdminNavItem('Funding Queue', Icons.pending_actions_outlined, Icons.pending_actions, '/superadmin/funding'),
  AdminNavItem('Transactions', Icons.receipt_long_outlined, Icons.receipt_long, '/superadmin/transactions'),
  AdminNavItem('Withdrawals Review', Icons.outbound_outlined, Icons.outbound, '/superadmin/withdrawals'),
  AdminNavItem('Flags Queue', Icons.flag_outlined, Icons.flag, '/superadmin/flags'),
  AdminNavItem('User Management', Icons.people_outline, Icons.people, '/superadmin/users'),
  AdminNavItem('Audit Log', Icons.history_edu_outlined, Icons.history_edu, '/superadmin/audit'),
];
