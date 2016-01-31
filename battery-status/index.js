const batteryStatus = require('bindings')('batterystatus.node');

module.exports = batteryStatus.get;
