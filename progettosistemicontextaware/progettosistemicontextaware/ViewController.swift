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
    var token: String?
    var sessionId: String?
    var latitude: String?
    var longitude: String?
    var activity: String?
    var repetitionTime: Double? = 5
    var temp: String? = ""
    
    // Elementi UI
    @IBOutlet weak var labelResponse: UILabel!
    @IBOutlet weak var labelLatitude: UILabel!
    @IBOutlet weak var labelLongitude: UILabel!
    @IBOutlet weak var labelActivity: UILabel!
    @IBOutlet weak var labelNotificationContent: UILabel!
    @IBOutlet weak var webViewOutput: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        overlay = UIView(frame: view.frame)
        overlay!.backgroundColor = UIColor.black
        overlay!.alpha = 1
        
        strLabel = UILabel(frame: CGRect(x: 105, y: 390, width: 250, height: 60))
        strLabel.text = "Caricamento in corso..."
        strLabel.font = .systemFont(ofSize: 20, weight: .medium)
        strLabel.textColor = UIColor(white: 1, alpha: 1)
        
        activityIndicator = UIActivityIndicatorView(style: .white)
        activityIndicator.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
        activityIndicator.startAnimating()
        activityIndicator.center = self.view.center
        
        view.addSubview(overlay!)
        view.addSubview(activityIndicator)
        view.addSubview(strLabel)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.startMotionDetection()
        self.determineMyCurrentLocation()
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            
            if self.temp != self.delegate.contentAppDelegate! {
                if self.delegate.contentAppDelegate!.hasPrefix("http") {
                    // Aggiorna dati UI
                    self.webViewOutput.load(self.delegate.contentAppDelegate!)
                    self.labelNotificationContent.text = "Notifica: \(self.delegate.contentAppDelegate!)"
                } else {
                    // Aggiorna dati UI
                    self.webViewOutput.load(URLRequest(url: URL(string:"about:blank")!))
                    self.labelNotificationContent.text = "Notifica: \(self.delegate.contentAppDelegate!)"
                }
            }
            self.temp = self.delegate.contentAppDelegate!
        }
        
        Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { timer in
            self.token = self.delegate.tokenAppDelegate
            self.registerUser()
        }
        
        Timer.scheduledTimer(withTimeInterval: repetitionTime!, repeats: true) { timer in
            
            self.determineMyCurrentLocation()
            
            /*
            // Test
            print("\nTOKEN: \(self.token ?? "Nessun token")\n")
            print("\nATTIVITÀ: \(self.activity!)")
            print("\nREPETITION TIME: \(self.repetitionTime!)")
            */
 
            // Aggiorna dati UI
            self.labelLatitude.text = "Latitudine: \(self.latitude!)"
            self.labelLongitude.text = "Longitudine: \(self.longitude!)"
            self.labelActivity.text = "Attività: \(self.activity!)"
            
            self.overlay?.removeFromSuperview()
            self.activityIndicator.removeFromSuperview()
            self.strLabel.removeFromSuperview()
            
            // Se l'utente è fermo non chiama communicatePosition()
            //if(self.activity != "stationary")
            //{
                self.communicatePosition()
            //}
            
            // Stop del timer
            //timer.invalidate()
        }
    }
    
    /*
    func updateLabelNotificationContent(notificationContent: String) {
        
        print("CONTENUTO NOTIFICA: \(notificationContent)")
        
        DispatchQueue.main.async() {
            print("PROVA")
            self.labelNotificationContent?.text = "Contenuto notifica: \(notificationContent)"
            //self.labelNotificationContent?.text = "AAA"
        }
    }
    */
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func registerUser(){
        var session = URLSession.shared
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)

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
                
                self.labelResponse.text = "Messaggio: \(message!)"
            } catch {
                print("\n JSON error: \(error.localizedDescription)")
            }
        })
        task.resume()
    }
    
    func communicatePosition(){
        var session = URLSession.shared
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)

        let url = URL(string: "http://10.0.1.5:8000/")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let parameters = ["action": "communicate-position", "session_id": sessionId, "longitude": longitude, "latitude": latitude, "activity": activity]

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
                
                self.labelResponse.text = "Messaggio: \(message!)"
            } catch {
                print("\n JSON error: \(error.localizedDescription)")
            }
        })
        task.resume()
    }
    
    func determineMyCurrentLocation() {
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
            // locationManager.startUpdatingHeading()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let userLocation:CLLocation = locations[0] as CLLocation
        
        // Call stopUpdatingLocation() to stop listening for location updates,
        // other wise this function will be called every time when user location changes.
        
        manager.stopUpdatingLocation()
        
        latitude = String(userLocation.coordinate.latitude)
        longitude = String(userLocation.coordinate.longitude)
        
        print("\nLatitudine: \(userLocation.coordinate.latitude)")
        print("Longitudine: \(userLocation.coordinate.longitude)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("Error \(error)")
    }
    
    func startMotionDetection() {
        DispatchQueue.global().async {
            self.activityManager.startActivityUpdates(to: OperationQueue()) { [weak self] motionActivity in
                guard self != nil else { return }
                
                guard let motionActivity = motionActivity else {
                    return
                }
                
                if motionActivity.stationary {
                    //self?.activity = "stationary"
                    self?.activity = "walk"
                    self?.repetitionTime = 3
                    print("L'utente è fermo")
                } else if motionActivity.walking {
                    self?.activity = "walk"
                    self?.repetitionTime = 5
                    print("L'utente cammina")
                } else if motionActivity.running {
                    self?.activity = "walk"
                    self?.repetitionTime = 7
                    print("L'utente corre")
                } else if motionActivity.automotive {
                    self?.activity = "car"
                    self?.repetitionTime = 20
                    print("L'utente è in auto")
                } else if motionActivity.cycling {
                    self?.activity = "bike"
                    self?.repetitionTime = 10
                    print("L'utente è in bicicletta")
                } else {
                    self?.activity = "unknown"
                    self?.repetitionTime = 5
                    print("Movimento sconosciuto")
                }
            }
        }
    }
}

extension WKWebView {
    func load(_ urlString: String) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            load(request)
        }
    }
}
