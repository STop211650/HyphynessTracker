import { supabase } from './supabase.ts'

// Check if the authenticated user is a super admin
export async function isSuperAdmin(userId: string): Promise<boolean> {
  const { data, error } = await supabase
    .from('users')
    .select('is_super_admin')
    .eq('id', userId)
    .single()

  if (error || !data) {
    return false
  }

  return data.is_super_admin === true
}

// Get user permissions for a specific operation
export async function getUserPermissions(userId: string, operation: string, resourceId?: string) {
  const isAdmin = await isSuperAdmin(userId)
  
  return {
    is_super_admin: isAdmin,
    can_view_all: isAdmin,
    can_edit_all: isAdmin,
    can_create_users: isAdmin,
    can_record_any_payment: isAdmin
  }
}