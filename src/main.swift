/* TODO
        Implement sending messages between several users:
            Implement spreading user lists around and keeping them fresh
                Implement user pings
                Implement new user procedure
            Implement sending messages
                Implement sending messages around as sender - scattering seeds
                Implement being carrier for a message
                    Not sending more if you've found the right person, not sending same message twice
        Implement actual fucking UI
 */

/* Okay let's trace back the user propogation process
 first a new user starts up and starts advertising
 They are discovered by everyone around them, and when they connect they are added to the list of users and also asked for their firstSeen.
    This is necessary because firstSeen is effectively an identifier, and if everyone just got the time they received the advertisement there wouldn't be agreement on who was around. This identifier is just a number that needs to be unique. It doesn't need to stay the same over time, though that might be useful
 
 They are then added to the list of people to poll, and they are polled every second or so.
 When they are polled they should give a list of all their users, which are then added to the list of users if they have a unique firstSeen identifier
 Then, when someone else polls you, you give them a list of all your users which has been updated. In this way, information propogates through the network at a minimum pace of 1s/node. Even if there are ten nodes in between two people, it should take only ten seconds before they see each other.
 */

import Foundation //useless comment
import CoreBluetooth

var selfUUID: String

do {
    selfUUID = try getHardwareUUID()
}
catch {
    selfUUID = getRandUUID()
}
print("String \(selfUUID) has length \(selfUUID.utf8.count)")

let identifierServiceUUID = CBUUID(string: "b839e0d3-de74-4493-860b-00600deb5e00")
let messageWriteDirectCharacteristicUUID = CBUUID(string: "fc36344b-bcda-40ca-b118-666ec767ab20")
let messageWriteOtherCharacteristicUUID = CBUUID(string: "6f083e6a-8a09-468f-898e-b16755a1bf61")
let userReadCharacteristicUUID = CBUUID(string: "b8e0fee5-d132-4410-a09f-e584e64a115d")
let getInitialUserCharacteristicUUID = CBUUID(string: "7ade0d09-f195-4afe-b476-675ee4476ddf")

// Initialize both Central and Peripheral

let central_man = CentralMan()
let periph_man = PeripheralMan()


var queue: DispatchQueue!
if #available(OSX 10.10, *) {
    queue = DispatchQueue.global(qos: DispatchQoS.QoSClass.default)
} else {
    print("This program can only be run on OSX 10.10 or greater. Please update.")
    exit(1)
}
central_man.centralManager = CBCentralManager(delegate: central_man, queue: queue)

var queue2: DispatchQueue!
if #available(OSX 10.10, *) {
    queue2 = DispatchQueue.global(qos: DispatchQoS.QoSClass.default)
} else {
    print("This program can only be run on OSX 10.10 or greater. Please update.")
    exit(1)
}
periph_man.peripheralManager = CBPeripheralManager(delegate: periph_man, queue: queue2)

// This version is slight faster than waiting for each of them in turn. It should be more or less as fast as possible within two milliseconds.

while (!(central_man.centralManager.state == .poweredOn) && !(periph_man.peripheralManager.state == .poweredOn)){
    usleep(1000)
}
if central_man.centralManager.state == .poweredOn {
    central_man.centralManager.scanForPeripherals(withServices:nil)
    while (!(periph_man.peripheralManager.state == .poweredOn)) {
        usleep(1000)
    }
    start_advertising(periph_man)
}
else if periph_man.peripheralManager.state == .poweredOn {
    start_advertising(periph_man)
    while (!(central_man.centralManager.state == .poweredOn)) {
        usleep(1000)
    }
    central_man.centralManager.scanForPeripherals(withServices:nil)
}

if #available(OSX 10.10,*){
    DispatchQueue.global(qos: .background).async { // Run background thread to update the list of users we have
        updateUserList()
    }
}
else {
    print("This program can only be run on OSX 10.10 or greater. Please update.")
    exit(1)
}

let usr1 = makeDummyUser()
usleep(1000)
let usr2 = makeDummyUser()
usleep(1000)
let usr3 = makeDummyUser()
usleep(1000)
let usr4 = makeDummyUser()
usleep(1000)
let usr5 = makeDummyUser()


 while(true) {
    print("Waiting for users to connect.")
    while (central_man.connectedUsers.count == 0){
        usleep(100000)
    }
    print("Found a user to connect to")
    let receivingUser = central_man.connectedUsers[0]
    print("Found user to connect to! Now sending text to \(receivingUser)")
    var toSend: String
    while (true){
        toSend = readLine()!
        if(receivingUser.peripheral!.state != .connected) {
            break
        }
        print("state is \(receivingUser.peripheral!.state == .connected)")
        print("Sending message \(toSend) to peripheral \(receivingUser.name)")
        do {
            try sendMessage(receivingUser, messageText: toSend)
        }
        catch is messageSendError {
            print("Unable to send message, likely due to cnnection issues. Removing this user from the queue")
            central_man.connectedUsers.remove(at:0) // Automatically gets the first available user
        }
    }
}
