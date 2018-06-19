pragma solidity 0.4.18;

// we need an enhanced version of payroll
import "../../../future-apps/payroll/contracts/Payroll.sol";

contract PayrollWithSeniority is Payroll {

    /** @dev Initialize
      */
    function tempInitialize() external {
        nextEmployee = 1;
    }

    /** @dev A check to see if an employee has seniority over another
     * @param _seniorEmployeeId The senior employee's id
     * @param _juniorEmployeeId The junior employee's id
     * @return True if given employee is senior
     */
    function hasSenioritiyOver
    (
        uint128 _seniorEmployeeId,
        uint128 _juniorEmployeeId
    )
        public
        view
        returns(bool)
    {
        return _getEmployeeStartDateSafe(_seniorEmployeeId) < _getEmployeeStartDateSafe(_juniorEmployeeId);
    }

    /** @dev An employee that doesn't exist would have a startDate of 0 which would imply higher seniority.
      * Empty employees are assigned current time as start date to correct this.
      * @param _employeeId Employee's identifier
      * @return Employee's start date
      */
    function _getEmployeeStartDateSafe
    (
        uint128 _employeeId
    )
        internal
        view
        returns (uint256)
    {
        uint256 startDate;
        (,,,,startDate) = this.getEmployee(_employeeId);
        return startDate > 0 ? startDate : getTimestamp();
    }
}