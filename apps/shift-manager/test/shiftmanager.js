// kill $(ps aux | grep 'ganache' | awk '{print $2}')
const ShiftManager = artifacts.require('ShiftManager');
const PayrollWithSeniority = artifacts.require('PayrollWithSeniority');
const _ = require('lodash');

function getTime(year, month, day, hour) {
  return Math.floor(new Date(`${month} ${day} ${year} ${hour}:00:00`).getTime() / 1000);
}

function getTimeShort(day, hour) {
  return getTime(2018, 'January', day, hour);
}

function createShift(employee, day, start, end) {
  return {employee, start: getTimeShort(day, start), end: getTimeShort(day, end)};
}

function mapShifts(shifts) {
  return {
    employees: _.map(shifts, 'employee'),
    starts: _.map(shifts, 'start'),
    ends: _.map(shifts, 'end')
  };
}

function scheduledHours(shifts, employee) {
  return _.sum(
    _(shifts)
      .filter({employee})
      .map((o) => { return o.end - o.start; })
      .value()
  );
}

contract('Shift Manager', (accounts) => {
  let shiftManager;
  let payroll;

  beforeEach('deply new contract', async () => {
    shiftManager = await ShiftManager.new();
    if (!payroll) {
      payroll = await PayrollWithSeniority.new();
      await payroll.tempInitialize();
      await payroll.addEmployeeWithNameAndStartDate(accounts[1], 1, '', getTime(2016, 'January', 1, 0));
      await payroll.addEmployeeWithNameAndStartDate(accounts[2], 1, '', getTime(2017, 'January', 1, 0));
      await payroll.addEmployeeWithNameAndStartDate(accounts[3], 1, '', getTime(2017, 'March', 1, 0));
      await payroll.addEmployeeWithNameAndStartDate(accounts[4], 1, '', getTime(2017, 'April', 1, 0));
      await payroll.addEmployee(accounts[5], 1);
    }
    await shiftManager.initialize(payroll.address);
  });

  it('should create shifts', async () => {
    let shifts = [
      createShift(1, 1, 9, 14),
      createShift(0, 1, 9, 14),
      createShift(1, 2, 9, 14),
    ];

    let mappedShifts = mapShifts(shifts);
    await shiftManager.addShifts(mappedShifts.employees, mappedShifts.starts, mappedShifts.ends);
    let shift0 = await shiftManager.getShift(0);
    assert.equal(shift0[0].toNumber(), shifts[0].employee, 'shift added'); 
    let hours = await shiftManager.employeeScheduledTime.call(shifts[0].employee);
    assert.equal(hours.toNumber(), scheduledHours(shifts, shifts[0].employee), 'hours worked');
  });

  it('should validate seniority', async () => {
    let hasSeniority = await payroll.hasSenioritiyOver(1, 2);
    assert.isTrue(hasSeniority, 'has seniority over');

    let doesNotHaveSeniority = await payroll.hasSenioritiyOver(2, 1);
    assert.isFalse(doesNotHaveSeniority, 'does not have seniority over');

    let hasSeniorityOverEmpty = await payroll.hasSenioritiyOver(4, 5);
    assert.isTrue(hasSeniorityOverEmpty, 'has seniority over not set start date');

    let notSetDoesNotHaveSeniority = await payroll.hasSenioritiyOver(5, 4);
    assert.isFalse(notSetDoesNotHaveSeniority, 'not set start date does not has seniority');
  });

  it('should allow users with more seniority take shifts', async () => {
    let shifts = [
      createShift(1, 1, 9, 14),
      createShift(0, 2, 9, 14),
      createShift(2, 3, 9, 14),
    ];
    let mappedShifts = mapShifts(shifts);
    await shiftManager.addShifts(mappedShifts.employees, mappedShifts.starts, mappedShifts.ends);
    await shiftManager.takeShift(1, 1, {from: accounts[1]});
    let shift = await shiftManager.getShift(1);
    assert.equal(shift[0].toNumber(), 1, 'employee was able to take unassigned shift');

    await shiftManager.takeShift(2, 1, {from: accounts[1]});
    let shift2 = await shiftManager.getShift(2);
    assert.equal(shift[0].toNumber(), 1, 'employee was able to take shift from less senior');
  });

  it('should allow users to offer and claim shifts', async () => {
    let shifts = [
      createShift(1, 1, 9, 14),
      createShift(2, 3, 9, 14)
    ];

    let mappedShifts = mapShifts(shifts);
    await shiftManager.addShifts(mappedShifts.employees, mappedShifts.starts, mappedShifts.ends);
    await shiftManager.offerShift(0, 1, {from: accounts[1]});
    await shiftManager.claimShift(0, 2, {from: accounts[2]});
    let shift = await shiftManager.getShift(0);
    assert.equal(shift[0].toNumber(), 2, 'employee claimed shift');
  });
});