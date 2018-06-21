# Shift Manager
## Description
A smart contract that allows for the scheduling and transferring of shifts for shift worker. A shift manager can create and assign a set of shifts to employees. Employees can then transfer shifts or even take shifts if they have seniority over the employee assigned to the shift.

This contract utilizes the [Payroll](https://github.com/aflesher/aragon-apps/tree/master/future-apps/payroll) aragon-app to create and manage the employees.

## Missing Features
1. `_addShift`, and `_takeShift` should verify that the shift does not overlap and existing shift for that user.
2. An account with the `SHIFT_MANAGER_ROLE` role should be able to disable the `takeShift` functionality
3. Funds should be distributed based on hours worked. This would require integration with the payroll contract to distribute the funds.
4. An account with the `SHIFT_MANAGER_ROLE` should be able to flag a shift as having not been worked. (more details required for this feature)
5. Overtime should be an optional feature with multiplier for overtime hours.
