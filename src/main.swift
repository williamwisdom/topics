import Foundation
import CoreBluetooth

//let periph_man = PeripheralMan()
//let central_man = CentralMan()
let periphMan = PeripheralMan()
start_advertising(periph_man:periphMan)


let standInUUID = CBUUID(string: "0x1800")
//var ids: [CBUUID] = [standInUUID]

//if(central_man.centralManager.state == .poweredOn) {
//    central_man.centralManager.scanForPeripherals(withServices: [standInUUID])
//}
//else {
//    print("CentralManager state is not powered on. Perhaps your bluetooth is off.")
//}

while (true){
    usleep(100000)
    //print("huH")
}

