pragma solidity 0.4.18;

import "./PayrollWithSeniority.sol";

import "@aragon/os/contracts/apps/AragonApp.sol";

contract ShiftManager is AragonApp {
    using SafeMath for uint256;
    bytes32 constant public SHIFT_MANAGER_ROLE = keccak256("SHIFT_MANAGER_ROLE");

    struct Shift {
        uint128 employeeId;
        uint256 startTime;
        uint256 endTime;
    }

    mapping (uint128 => uint256) public employeeScheduledTime;
    mapping (uint256 => bool) private offeredShifts;

    Shift[] private shifts;
    PayrollWithSeniority payroll;
    uint256 private maxScheduleTime = 144000; // 40 hours

    function initialize(
        PayrollWithSeniority _payroll
    )
        external
        onlyInit
    {
        initialized();
        payroll = _payroll;
    }

    modifier doesNotExceedMaxHours(
        uint128 _employeeId,
        uint256 _startTime,
        uint256 _endTime
    ) {
        require(employeeScheduledTime[_employeeId].add(_endTime.sub(_startTime)) < maxScheduleTime);
        _;
    }

    event ShiftAdded(uint128 employeeId, uint256 startTime, uint256 endTime);
    event ShiftTaken(uint128 assignedEmployeeId, uint128 unassignedEmployeeId, uint256 startTime, uint256 endTime);
    event ShiftClaimed(uint128 assignedEmployeeId, uint128 unassignedEmployeeId, uint256 startTime, uint256 endTime);
    event ShiftOffered(uint128 employeeId, uint256 startTime, uint256 endTime);

    /** @dev Checks that the given start times are valid
      * @param _startTime Start time
      * @param _endTime End time
      * @return True if the times are valid
      */
    function _validateShiftTimes(
        uint256 _startTime,
        uint256 _endTime
    )
        internal
        returns(bool)
    {
        return _startTime > 0 && _endTime > _startTime;
    }

    /** @dev Adds hours to an employee's scheduled hours
      * @param _employeeId The employee's id to add hours to
      * @param _startTime the start time
      * @param _endTime the end time
      */
    function _addScheduledHours(
        uint128 _employeeId,
        uint256 _startTime,
        uint256 _endTime
    )
        internal
        doesNotExceedMaxHours(_employeeId, _startTime, _endTime)
    {
        if (_employeeId > 0) {
            employeeScheduledTime[_employeeId] = employeeScheduledTime[_employeeId].add(_endTime.sub(_startTime));
        }
    }

    /** @dev Subtract from an employee's scheduled hours
      * @param _employeeId The employee's id to subtract hours from
      * @param _startTime the start time
      * @param _endTime the end time
      */
    function _subtractScheduledHours(
        uint128 _employeeId,
        uint256 _startTime,
        uint256 _endTime
    )
        internal
    {
        if (_employeeId > 0) {
            employeeScheduledTime[_employeeId] = employeeScheduledTime[_employeeId].sub(_endTime.sub(_startTime));
        }
    }

    /** @dev Adds a shift
      * @param _employeeId The shift is assigned to or 0 if unassigned
      * @param _startTime The shift start time
      * @param _endTime The shift end time
      */
    function _addShift(
        uint128 _employeeId,
        uint256 _startTime,
        uint256 _endTime
    )
        internal
    {
        require(_validateShiftTimes(_startTime, _endTime));
        _addScheduledHours(_employeeId, _startTime, _endTime);
        shifts.push(Shift({
            employeeId: _employeeId,
            startTime: _startTime,
            endTime: _endTime
        }));
        ShiftAdded(_employeeId, _startTime, _endTime);
    }

    /** @dev Adds some shifts
      * @param _employeeIds An array of employee ids to assign the shifts to or an array of 0's if unassigned
      * @param _startTimes An array of shift start times
      * @param _endTimes An array of shift end times
      */
    function addShifts(
        uint128[] _employeeIds,
        uint256[] _startTimes,
        uint256[] _endTimes
    )
        external
        auth(SHIFT_MANAGER_ROLE)
    {
        for (uint i = 0; i < _employeeIds.length; i++) {
            _addShift(_employeeIds[i], _startTimes[i], _endTimes[i]);
        }
    }

    /** @dev Gets a shift
      * @param _shiftIndex The index of the shift
      * @return employeeId The shift workers id
      * @return startTime The shift start time
      * @return endTime The shift end time
      */
    function getShift(
        uint _shiftIndex
    )
        public view
        returns (uint128 employeeId, uint256 startTime, uint256 endTime)
    {
        Shift storage shift = shifts[_shiftIndex];
        employeeId = shift.employeeId;
        startTime = shift.startTime;
        endTime = shift.endTime;
    }

    function _transferShift(
        uint256 _shiftIndex,
        uint128 _employeeId
    )
        private
    {
        Shift storage shift = shifts[_shiftIndex];
        uint128 oldEmployeeId = shift.employeeId;
        shift.employeeId = _employeeId;
        _subtractScheduledHours(oldEmployeeId, shift.startTime, shift.endTime);
        _addScheduledHours(_employeeId, shift.startTime, shift.endTime);
    }

    /** @dev Allows a more senior employee to take a shift for another employee
      * @param _shiftIndex The shift to take
      * @param _employeeId The employee's id that is attempting to take the shift
      */
    function takeShift(
        uint _shiftIndex,
        uint128 _employeeId
    )
        external
    {
        Shift storage shift = shifts[_shiftIndex];
        require(
            payroll.addressBelongsToEmployee(_employeeId, msg.sender) &&
            _validateShiftTimes(shift.startTime, shift.endTime) &&
            payroll.hasSenioritiyOver(_employeeId, shift.employeeId)
        );
        uint128 oldEmployeeId = shift.employeeId;
        _transferShift(_shiftIndex, _employeeId);
        ShiftTaken(_employeeId, oldEmployeeId, shift.startTime, shift.endTime);
    }

    /** @dev Allows an employee to offer a shift
      * @param _shiftIndex The shift index
      * @param _employeeId The shift owners id
      */
    function offerShift(
        uint _shiftIndex,
        uint128 _employeeId
    )
        external
    {
        Shift storage shift = shifts[_shiftIndex];
        require(
            payroll.addressBelongsToEmployee(_employeeId, msg.sender) &&
            shift.employeeId == _employeeId
        );
        offeredShifts[_shiftIndex] = true;
        ShiftOffered(_employeeId, shift.startTime, shift.endTime);
    }

    /** @dev Allows an employee to claim a shift offered by another employee
      * @param _shiftIndex The shift index
      * @param _employeeId The employee claiming the shift
      */
    function claimShift(
        uint _shiftIndex,
        uint128 _employeeId
    )
        external
    {
        Shift storage shift = shifts[_shiftIndex];
        require(
            payroll.addressBelongsToEmployee(_employeeId, msg.sender) &&
            offeredShifts[_shiftIndex] == true
        );
        uint128 oldEmployeeId = shift.employeeId;
        _transferShift(_shiftIndex, _employeeId);
        offeredShifts[_shiftIndex] == false;
        ShiftClaimed(_employeeId, oldEmployeeId, shift.startTime, shift.endTime);
    }
}