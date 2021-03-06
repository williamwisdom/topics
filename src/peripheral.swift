/* Mostly "inspired" by https://medium.com/@shu223/core-bluetooth-snippets-with-swift-9be8524600b2 */

import Foundation
import CoreBluetooth

class PeripheralMan: NSObject, CBPeripheralManagerDelegate {
    var peripheralManager: CBPeripheralManager!
    
    

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager)
    {
    }
    

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?)
    {
        if let error = error {
            print("Failed… error: \(error)")
            return
        }
    }

    func peripheralManager(peripheral: CBPeripheralManager, didAdd service: CBService, error: NSError?)
    {
        if let error = error {
            print("error: \(error)")
            return
        }

        print("service: \(service)")
    }
    func peripheralManager(_: CBPeripheralManager, didReceiveRead: CBATTRequest){
        print("maximumUpdateValueLength is \(didReceiveRead.central.maximumUpdateValueLength)")
        let characteristic = didReceiveRead.characteristic
        print("Received read: \(didReceiveRead)")
        if (characteristic.uuid == userReadCharacteristicUUID){
            print("Attempted to get update user list")
            let responseData = NSMutableData(length: 0)! // length=0 because we will be appending
            
            for usr in allUsers {
                let userData = usr.user_to_data()
                var userLength = Int32(userData.length) // var so we can reference memory location
                responseData.append(NSData(bytes: &userLength, length:4) as Data)
                responseData.append(userData as Data)
                print("Sent over user \(usr) with length \(userLength)")
            }
            
            didReceiveRead.value = responseData as Data
            print("Sent response to userRead: \(responseData)")
            peripheralManager.respond(to: didReceiveRead, withResult: CBATTError.Code.success)
            print("userRead success")
        }
        else if (characteristic.uuid == getInitialUserCharacteristicUUID) {
            
            didReceiveRead.value = selfUser.user_to_data() as Data
            print("We are being asked for our user data. We are responding with \(didReceiveRead.value! as NSData)")
            
            peripheralManager.respond(to: didReceiveRead, withResult: CBATTError.Code.success)
        }
        else {
            print("Received read request for characteristic other than userReadCharacteristic: \(characteristic)")
            peripheralManager.respond(to: didReceiveRead, withResult: CBATTError.Code.attributeNotFound)
        }
    }
    
    func peripheralManager(_: CBPeripheralManager, didReceiveWrite: [CBATTRequest]) { // In respond to write request
        print("maximumUpdateValueLength is \(didReceiveWrite[0].central.maximumUpdateValueLength)")
        for request in didReceiveWrite {
            if (request.characteristic.uuid == messageWriteDirectCharacteristicUUID) {
                let msg = data_to_message(_: request.value! as NSData)
                receiveMessage(msg)
                peripheralManager.respond(to: request, withResult: CBATTError.Code.success)
            }
            else if (request.characteristic.uuid == messageWriteOtherCharacteristicUUID){
                let msg = data_to_message(_: didReceiveWrite[0].value! as NSData)
                if msg.receivingUser == selfUser {
                    receiveMessage(msg)
                }
                    
                else if msg.sendingUser == selfUser {
                    print("Received message sent by us. This is a bug and should not happen")
                }
                    
                else { // Message sent by somebody else to somebody else - we should help route.
                    // Check if we've already seen the message
                    
                    if recentMessages.contains(msg) == true {
                        peripheralManager.respond(to: request, withResult: CBATTError.Code.success) // Just do nothing
                    }
                        
                    else {
                        recentMessages.insert(msg)
                        for user in central_man.connectedUsers {
                            if (user.peripheral!.state != .connected){
                                continue // This gets most disconnections, but it won't get it sometimes
                            }
                            do {
                                let writeCharacteristic = try getCharacteristic(user.peripheral!, characteristicUUID: messageWriteOtherCharacteristicUUID)
                                user.peripheral!.writeValue(msg.message_to_data() as Data, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
                                peripheralManager.respond(to: request, withResult: CBATTError.Code.success)
                            }
                            catch { //
                                print("messageSendError when trying to propogate")
                            }
                        }
                    }
                }
            }
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
    }
}



