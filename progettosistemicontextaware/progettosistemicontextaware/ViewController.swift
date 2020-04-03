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
    //var activityTypeLocation: String? = ""
    
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
            print("TIMER1 \(self.defaultTimer)")
            // Aggiorna dati UI e lancia communicatePosition()
            Timer.scheduledTimer(withTimeInterval: self.defaultTimer, repeats: true) { timer in
                
                // Se l'utente è fermo, unknown o il session ID non è stato setato correttamente durante la registrazione dell'utente non lancia communicatePosition()
                if((self.activity != "stationary") && (self.activity != "unknown") && (self.sessionId != "")) {
                    self.determineMyCurrentLocation()
                    
                    let coordinatePrevious = CLLocation(latitude: (self.latitudePrevious! as NSString).doubleValue, longitude: (self.longitudePrevious! as NSString).doubleValue)
                    let coordinateActual = CLLocation(latitude: (self.latitude! as NSString).doubleValue, longitude: (self.longitude! as NSString).doubleValue)

                    let distanceMeters = coordinatePrevious.distance(from: coordinateActual)
                    
                    // Aggiorna dati precedenti
                    self.latitudePrevious = self.latitude
                    self.longitudePrevious = self.longitude
                    self.activityPrevious = self.activity
                    
                    print(distanceMeters)
                    
                    self.toSend = true
                    if((self.activity == self.activityPrevious) && (distanceMeters < 50)) {
                        self.toSend = false
                    }
                    
                    if(self.toSend) {
                        // Aggiorna dati UI
                        self.labelLatitude.text = "Latitudine: \(self.latitude!)"
                        self.labelLongitude.text = "Longitudine: \(self.longitude!)"
                        self.labelActivity.text = "Attività: \(self.activity!)"
                        
                        self.communicatePosition()
                        
                        self.defaultTimer = self.activityTimer!
                        print("BBB")
                    } else {
                        print("AAA \(self.defaultTimer)")
                        let tempTimer = pow(self.defaultTimer, 1.2)
                        self.defaultTimer = tempTimer
                    }
                } else {
                    self.labelActivity.text = "Attività: \(self.activity!)"
                    print("Utente fermo, movimento sconosciuto o Session ID non ricevuto")
                }
                print("TIMER2 \(self.defaultTimer)")
            }
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
    func communicatePosition(){
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

        let parameters: [String: Any] = ["type": "Feature", "geometry": ["type": "Point", "coordinates": [latitude, longitude]], "properties": ["action": "communicate-position", "session_id": sessionId, "activity": activity]]

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
