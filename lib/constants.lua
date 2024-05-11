--
-- Constants used in the code
--

local iopins = require('lib.iopins')

local const = {}

const.mod_prefix = '__fiber-optics__'
const.prefix = "hps:fo-"
-- prefix any name with the internal constant prefix
const.with_prefix = function(self, value) return self.prefix .. value end

const.optical_connector = const:with_prefix('optical-connector')
const.optical_connector_technology = const:with_prefix('optical-connector-technology')
const.oc_power_interface = const:with_prefix('oc-power-interface')
const.oc_power_pole = const:with_prefix('oc-power-pole')
const.oc_led_lamp = const:with_prefix('oc-led-lamp')
const.oc_cc = const:with_prefix('oc-constant-combinator')

-- network specific stuff
const.network_connector = const:with_prefix('network-connector')

const.attached_entities = {
    const.oc_power_interface,
    const.oc_power_pole,
    const.oc_led_lamp,
    const.oc_cc,
}

const.empty_sprite = {
    filename = '__core__/graphics/empty.png',
    width = 1,
    height = 1,
}

const.circuit_wire_connectors = {
    wire = { red = { 0, 0 }, green = { 0, 0 } },
    shadow = { red = { 0, 0 }, green = { 0, 0 } },
}

const.directions = { defines.direction.north, defines.direction.west, defines.direction.south, defines.direction.east }

const.msg_wires_too_long = const.prefix .. 'messages.wires_too_long'

iopins.setup(const)

return const
