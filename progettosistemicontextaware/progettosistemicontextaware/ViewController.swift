//
//  ViewController.swift
//  progettosistemicontextaware
//
//  Created by Lorenzo Lanzarone on 04/03/2020.
//  Copyright © 2020 Università di Bologna. All rights reserved.
//

import UIKit
import CoreLocation
import CoreMotion
import WebKit

class ViewController: UIViewController, CLLocationManagerDelegate, WKNavigationDelegate {
    
    var overlay : UIView?
    var activityIndicator = UIActivityIndicatorView()
    var strLabel = UILabel()
    var locationManager:CLLocationManager!
    private let manager = CMMotionManager()
    private let activityManager = CMMotionActivityManager()
    let delegate = UIApplication.shared.delegate as! AppDelegate
    var token: String? = ""
    var sessionId: String? = ""
    var latitude: String? = ""
    var longitude: String? = ""
    var activity: String? = ""
    var latitudePrevious: String? = ""
    var longitudePrevious: String? = ""
    var activityPrevious: String? = ""
    var activityTimer: Double? = 5
    var defaultTimer: Double = 5
    var temp: String? = ""
    let imgView = UIImageView()
    var toSend: Bool = true
    var timeInterval: Double = 5
    var positionId: String? = ""
    
    // Elementi UI
    @IBOutlet weak var labelLatitude: UILabel!
    @IBOutlet weak var labelLongitude: UILabel!
    @IBOutlet weak var labelActivity: UILabel!
    @IBOutlet weak var webViewOutput: WKWebView!
    @IBOutlet weak var scrollNotificationContent: UITextView!
    @IBOutlet weak var scrollResponse: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Elementi UI caricamento app
        overlay = UIView(frame: view.frame)
        overlay!.backgroundColor = UIColor.white
        overlay!.alpha = 1
        
        imgView.frame = CGRect(x: 145, y: 188, width: 120, height: 120)
        imgView.image = UIImage(named: "Image")
        
        strLabel = UILabel(frame: CGRect(x: 65, y: 405, width: 300, height: 60))
        strLabel.text = "Caricamento di GeoJoy in corso..."
        strLabel.font = .systemFont(ofSize: 20, weight: .medium)
        strLabel.textColor = UIColor.black
        
        activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
        activityIndicator.startAnimating()
        activityIndicator.center = self.view.center
        
        self.webViewOutput.isHidden = true
        view.addSubview(overlay!)
        view.addSubview(imgView)
        view.addSubview(activityIndicator)
        view.addSubview(strLabel)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Lancia riconoscimento attività e prima localizzazione
        self.startMotionDetection()
        self.determineMyCurrentLocation()
        
        // Gestione apertura notifica da parte dell'utente
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if self.temp != self.delegate.contentAppDelegate! {
                if self.delegate.contentAppDelegate!.hasPrefix("http") {
                    // Aggiorna dati UI, notifica con URL
                    self.webViewOutput.isHidden = false
                    self.webViewOutput.load(self.delegate.contentAppDelegate!)
                    self.scrollNotificationContent.text = "Notifica: \(self.delegate.contentAppDelegate!)"
                } else {
                    // Aggiorna dati UI, notifica con testo
                    self.webViewOutput.isHidden = true
                    self.scrollNotificationContent.text = "Notifica: \(self.delegate.contentAppDelegate!)"
                }
            }
            self.temp = self.delegate.contentAppDelegate!
        }
        
        // Preleva il token di Firebase e lancia registerUser()
        Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { timer in
            self.token = self.delegate.tokenAppDelegate
            self.registerUser()
            
            // Rimuovi elementi UI caricamento app
            self.overlay?.removeFromSuperview()
            self.imgView.removeFromSuperview()
            self.activityIndicator.removeFromSuperview()
            self.strLabel.removeFromSuperview()
            
            // Aggiorna dati UI
            self.labelLatitude.text = "Latitudine: \(self.latitude!)"
            self.labelLongitude.text = "Longitudine: \(self.longitude!)"
            self.labelActivity.text = "Attività: \(self.activity!)"
            
            print("TIMER 1: \(self.timeInterval)")
            
            Timer.scheduledTimer(timeInterval: self.timeInterval, target: self, selector: #selector(self.onTimer), userInfo: nil, repeats: true)
        }
    }
    
    @objc func onTimer(timer: Timer) {
        print("TIMER 2: \(self.timeInterval)")
        print("Contenuto realPositionId: \(self.delegate.realPositionIdAppDelegate)")
        
        // Se l'utente è fermo, unknown o il session ID non è stato setato correttamente durante la registrazione dell'utente non lancia communicatePosition()
        if((self.activity != "stationary") && (self.activity != "unknown") && (self.sessionId != "")) {
            let activityToSend = self.activity!
            
            self.determineMyCurrentLocation()
            
            let coordinatePrevious = CLLocation(latitude: (self.latitudePrevious! as NSString).doubleValue, longitude: (self.longitudePrevious! as NSString).doubleValue)
            let coordinateActual = CLLocation(latitude: (self.latitude! as NSString).doubleValue, longitude: (self.longitude! as NSString).doubleValue)

            let distanceMeters = coordinatePrevious.distance(from: coordinateActual)
            
            print("Distanza calcolata: \(distanceMeters)")
            
            // Aggiorna dati precedenti
            self.latitudePrevious = self.latitude
            self.longitudePrevious = self.longitude
            self.activityPrevious = self.activity
            
            // Aggiorna dati UI
            self.labelLatitude.text = "Latitudine: \(self.latitude!)"
            self.labelLongitude.text = "Longitudine: \(self.longitude!)"
            self.labelActivity.text = "Attività: \(self.activity!)"
            
            self.toSend = true
            if((self.activity == self.activityPrevious) && (distanceMeters < 50)) {
                self.toSend = false
            }
            
            if(self.toSend) {                
                let numberOfFakePosition: Int = 9
                var arrayOfArrayData = [[String]]()
                var arrayData = [String]()
                
                // Generazione session ID vero
                positionId = String.random()
                
                print("positionId: \(positionId!)")
                print("latitude: \(latitude!)")
                print("longitude: \(longitude!)")
                
                // Aggiunta position ID vero all'array dei position ID veri
                self.delegate.realPositionIdAppDelegate.append(positionId!)
                
                // Aggiunta position ID e posizioni vere
                arrayData.append(positionId!)
                arrayData.append(latitude!)
                arrayData.append(longitude!)
                
                arrayOfArrayData.append(arrayData)
                
                // Generzione posizioni finte
                let myLocation = CLLocation(latitude: (self.latitude! as NSString).doubleValue, longitude: (self.longitudePrevious! as NSString).doubleValue)
                let locationsArray = getMockLocationsFor(location: myLocation, itemCount: numberOfFakePosition)
                
                for i in 0...(numberOfFakePosition - 1) {
                    arrayData.removeAll()
                    
                    // Generazione e aggiunta session ID finti
                    arrayData.append(String.random())
                    
                    // Aggiunta posizioni finte
                    arrayData.append(String(locationsArray[i].coordinate.latitude))
                    arrayData.append(String(locationsArray[i].coordinate.longitude))
                    
                    arrayOfArrayData.append(arrayData)
                    
                    arrayData.removeAll()
                }
                
                // Mischia l'array di array
                arrayOfArrayData.shuffle()
                
                print(arrayOfArrayData)
                
                // Invia tutti i dati al server
                var count : Int = 0
                
                Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer2 in
                    if(count <= numberOfFakePosition){
                        
                        //print(count)
                        //print(arrayOfArrayData[count][0])
                        //print(arrayOfArrayData[count][1])
                        //print(arrayOfArrayData[count][2])
                        //print("\n")
                        
                        self.communicatePosition(positionIdtoSend: arrayOfArrayData[count][0], latitudeToSend: arrayOfArrayData[count][1], longitudeToSend: arrayOfArrayData[count][2], activityToSend: activityToSend)
                        count += 1
                    } else{
                        timer2.invalidate()
                        arrayOfArrayData.removeAll()
                        
                        self.timeInterval = self.activityTimer!
                        timer.fireDate = timer.fireDate.addingTimeInterval(self.timeInterval)
                        print("LONTANO: \(self.timeInterval)")
                    }
                }
            } else {
                switch self.activity! {
                case "walk":
                    timeInterval = pow(timeInterval, 1.2)
                    timer.fireDate = timer.fireDate.addingTimeInterval(timeInterval)
                    print("VICINO walk: \(timeInterval)")
                case "bike":
                    timeInterval = pow(timeInterval, 1.1)
                    timer.fireDate = timer.fireDate.addingTimeInterval(timeInterval)
                    print("VICINO bike: \(timeInterval)")
                case "car":
                    timeInterval = pow(timeInterval, 1.05)
                    timer.fireDate = timer.fireDate.addingTimeInterval(timeInterval)
                    print("VICINO car: \(timeInterval)")
                default:
                    timeInterval = pow(timeInterval, 1.2)
                    timer.fireDate = timer.fireDate.addingTimeInterval(timeInterval)
                    print("VICINO default: \(timeInterval)")
                }
            }
        } else {
            self.labelActivity.text = "Attività: \(self.activity!)"
            print("Utente fermo, movimento sconosciuto o Session ID non ricevuto")
            timeInterval = self.activityTimer!
            timer.fireDate = timer.fireDate.addingTimeInterval(timeInterval)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // Registra l'utente nel database comunicando con il backend
    func registerUser(){
        var session = URLSession.shared
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)

        // Modificare IP server se necessario
        let url = URL(string: "http://10.0.1.5:8000/")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let parameters = ["action": "register", "registration_token": token]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
        } catch let error {
            print(error.localizedDescription)
        }

        let task = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in

            if error != nil || data == nil {
                print("\n Client error! \n")
                return
            }

            guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                print("\n Oops!! there is server error! \n")
                return
            }

            guard let mime = response.mimeType, mime == "application/json" else {
                print("\n response is not json \n")
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String:Any]
                let result = json?["result"] as? Bool
                let message = json?["message"] as? String
                self.sessionId = json?["session_id"] as? String
                
                print("\nRisultato: \(result!)")
                print("Messaggio: \(message!)")
                print("Session ID: \(self.sessionId!)")
                
                self.scrollResponse.text = "Messaggio: \(message!)"
            } catch {
                print("\n JSON error: \(error.localizedDescription)")
            }
        })
        task.resume()
    }
    
    // Registra la nuova posizione nel database comunicando con il backend
    func communicatePosition(positionIdtoSend: String, latitudeToSend: String, longitudeToSend: String, activityToSend: String){
        var session = URLSession.shared
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)

        // Modificare IP server se necessario
        let url = URL(string: "http://10.0.1.5:8000/")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let parameters: [String: Any] = ["type": "Feature", "geometry": ["type": "Point", "coordinates": [latitudeToSend, longitudeToSend]], "properties": ["action": "communicate-position", "session_id": sessionId, "position_id_device": positionIdtoSend, "activity": activityToSend]]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
        } catch let error {
            print(error.localizedDescription)
        }

        let task = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in

            if error != nil || data == nil {
                print("\n Client error! \n")
                return
            }

            guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                print("\n Oops!! there is server error! \n")
                return
            }

            guard let mime = response.mimeType, mime == "application/json" else {
                print("\n response is not json \n")
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String:Any]
                let result = json?["result"] as? Bool
                let message = json?["message"] as? String
                self.sessionId = json?["session_id"] as? String
                
                print("\nRisultato: \(result!)")
                print("Messaggio: \(message!)")
                print("Session ID: \(self.sessionId!)")
                
                self.scrollResponse.text = "Messaggio: \(message!)"
            } catch {
                print("\n JSON error: \(error.localizedDescription)")
            }
        })
        task.resume()
    }
    
    // Gestione recupero della posizione
    func determineMyCurrentLocation() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let userLocation:CLLocation = locations[0] as CLLocation
        
        latitude = String(userLocation.coordinate.latitude)
        longitude = String(userLocation.coordinate.longitude)
        
        // Test output
        print("\nLatitudine: \(userLocation.coordinate.latitude)")
        print("Longitudine: \(userLocation.coordinate.longitude)")
        
        // Interrompi aggiornamento posizione, verrà rilanciato solo ad ogni ciclo del timer
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error \(error)")
    }
    
    // Gestione riconoscimento attività
    func startMotionDetection() {
        DispatchQueue.global().async {
            self.activityManager.startActivityUpdates(to: OperationQueue()) { [weak self] motionActivity in
                guard self != nil else { return }
                
                guard let motionActivity = motionActivity else {
                    return
                }
                
                if motionActivity.stationary {
                    self?.activity = "stationary"
                    self?.activityTimer = 5
                    print("L'utente è fermo")
                } else if motionActivity.walking {
                    self?.activity = "walk"
                    self?.activityTimer = 5
                    print("L'utente cammina")
                } else if motionActivity.running {
                    self?.activity = "walk"
                    self?.activityTimer = 5
                    print("L'utente corre")
                } else if motionActivity.automotive {
                    self?.activity = "car"
                    self?.activityTimer = 20
                    print("L'utente è in auto")
                } else if motionActivity.cycling {
                    self?.activity = "bike"
                    self?.activityTimer = 10
                    print("L'utente è in bicicletta")
                } else {
                    self?.activity = "unknown"
                    self?.activityTimer = 5
                    print("Movimento sconosciuto")
                }
            }
        }
    }
    
    // Crea posizioni random vicine alla reale posizione dell'utente
    func getMockLocationsFor(location: CLLocation, itemCount: Int) -> [CLLocation] {
        
        func getBase(number: Double) -> Double {
            return round(number * 1000)/1000
        }
        
        func randomCoordinate() -> Double {
            return Double(arc4random_uniform(140)) * 0.0001
        }
        
        let baseLatitude = getBase(number: location.coordinate.latitude - 0.007)
        // longitude is a little higher since I am not on equator, you can adjust or make dynamic
        let baseLongitude = getBase(number: location.coordinate.longitude - 0.008)
        
        var items = [CLLocation]()
        for _ in 0..<itemCount {
            
            let randomLat = baseLatitude + randomCoordinate()
            let randomLong = baseLongitude + randomCoordinate()
            let location = CLLocation(latitude: randomLat, longitude: randomLong)
            
            items.append(location)
        }
        
        return items
    }
}

// Gestione caricamento pagine WebView
extension WKWebView {
    func load(_ urlString: String) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            load(request)
        }
    }
}

// Genarazione stringa alfanumerica random
extension String {
    static func random(length: Int = 20) -> String {
        let base = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString: String = ""

        for _ in 0..<length {
            let randomValue = arc4random_uniform(UInt32(base.count))
            randomString += "\(base[base.index(base.startIndex, offsetBy: Int(randomValue))])"
        }
        return randomString
    }
}
