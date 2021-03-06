//
//  AudioRecordViewController.swift
//  AVNotes
//
//  Created by Kevin Miller on 12/5/17.
//  Copyright © 2017 Kevin Miller. All rights reserved.
//

import AudioKit
import AudioKitUI
import AVKit
import Firebase
import MaterialComponents.MaterialFeatureHighlight
import UIKit

enum Mode {
    case playback
    case record
}

let bookmarkModal = "bookmarkModal"
let mainStoryboard = "Main"

class AudioRecordViewController: UIViewController { // swiftlint:disable:this type_body_length

    enum Constants {
        static let animationDuation = 0.33
        static let bookmarkModal = "bookmarkModal"
        static let cellIdentifier = "annotationCell"
        static let cornerRadius: CGFloat = 10.0
        static let emptyTableText = "No bookmarks here yet. To create a bookmark, start recording or playback and then press the \"New Bookmark\" button." // swiftlint:disable:this line_length
        static let emptyTimeString = "00:00.00"
        static let firstViewing = "firstViewing"
        static let insetConstant: CGFloat = 3.0
        static let mainStoryboard = "Main"
        static let onePixel: CGFloat = 1 / UIScreen.main.scale
        static let placeholderColor = UIColor(red:0.45, green:0.35, blue:0.50, alpha:1.0)
        static let playbackLineWidth: CGFloat = 1 / UIScreen.main.scale
        static let recordAlertMessage = "Start recording before adding a bookmark"
        static let recordAlertTitle = "Press Record"
        static let skipVC = "skipVC"
        static let skipVCHeight: CGFloat = 150
        static let textColor: UIColor = UIColor(red:0.08, green:0.07, blue:0.35, alpha:1.0)
        static let trailingInset: CGFloat = 0.06
        static let tableViewInset: CGFloat = 24.0
        static let timerInterval = 0.03
        static let titleFont = "montserrat"
        static let toFileView = "toFileView"
        static let viewSize: CGFloat = 150.0
        static let zeroString = "00:00"
    }

    enum AlertConstants {
        static let areYouSure =
        "Are you sure you wish to discard this recording? This action cannot be undone."
        static let bookmarks = "Bookmarks"
        static let cancel = "Cancel"
        static let discard = "Discard"
        static let enterTitle = "Enter a title for this recording"
        static let export = "Export:"
        static let newRecording = "New Recording"
        static let recording = "Recording"
        static let recordingSaved = "Your recording has been saved."
        static let save = "Save"
        static let success = "Success"
    }

    enum ImageConstants {
        static let replay5 = "ic_replay_5_white_48pt"
        static let replay10 = "ic_replay_10_white_48pt"
        static let replay30 = "ic_replay_30_white_48pt"
        static let forward5 = "ic_forward_5_white_48pt"
        static let forward10 = "ic_forward_10_white_48pt"
        static let forward30 = "ic_forward_30_white_48pt"
        static let pauseImage = "ic_pause_circle_outline_48pt"
        static let playImage = "ic_play_circle_outline_48pt"
        static let recordImage = "ic_fiber_manual_record_48pt"
        static let thumbImage = "ic_fiber_manual_record_white_18pt"
    }

    // MARK: IBOutlets
    @IBOutlet private weak var addBookmarkButton: UIButton!
    @IBOutlet private weak var addButtonSuperview: UIView!
    @IBOutlet private weak var annotationTableView: UITableView!
    @IBOutlet private var audioPlot: EZAudioPlot!
    @IBOutlet private weak var controlView: UIView!
    @IBOutlet private weak var discardButton: UIButton!
    @IBOutlet private var filesButton: UIBarButtonItem!
    @IBOutlet private var gradientView: GradientView!
    @IBOutlet private weak var playPauseButton: UIButton!
    @IBOutlet private weak var playStackView: UIStackView!
    @IBOutlet private var plusButton: UIBarButtonItem!
    @IBOutlet private weak var recordButton: UIButton!
    @IBOutlet private var recordStackLeading: NSLayoutConstraint!
    @IBOutlet private var recordStackTrailing: NSLayoutConstraint!
    @IBOutlet private weak var recordStackView: UIStackView!
    @IBOutlet private var scrubSlider: UISlider!
    @IBOutlet private var shareButton: UIButton!
    @IBOutlet private weak var skipBackButton: UIButton!
    @IBOutlet private weak var skipForwardButton: UIButton!
    @IBOutlet private weak var stopWatchLabel: UILabel!
    @IBOutlet private weak var waveformView: BorderDrawingView!

    // MARK: Private Vars
    private let fileManager = RecordingManager.sharedInstance
    private var forwardSkipValue: Double = 10
    private lazy var gradientManager = GradientManager()
    private lazy var isInitialFirstViewing = true
    private lazy var isShowingRecordingView = true
    private let mediaManager = AudioManager.sharedInstance
    private weak var modalTransitioningDelegate = CustomModalPresentationManager()
    private var playbackLine: UIView?
    private var playbackLineCenter: NSLayoutConstraint?
    private var playStackLeading: NSLayoutConstraint?
    private var playStackTrailing: NSLayoutConstraint?
    private var reverseSkipValue: Double = 10
    private var stateManager = StateManager.sharedInstance
    private var timer: Timer?

    // MARK: AudioKit Vars
    private var microphone: AKMicrophone!
    private var livePlot: AKNodeOutputPlot?
    private var summaryPlot: EZAudioPlot?

    // MARK: Lifecycle functions
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layoutIfNeeded() // Fixes unwanted implicit autolayout animations at launch
        AKSettings.audioInputEnabled = true
        microphone = AKMicrophone()
        stateManager.viewDelegate = self
        stateManager.currentState = .initialize
        mediaManager.bookmarkTableViewDelegate = self
        definesPresentationContext = true
        NotificationCenter.default.addObserver(self, selector: #selector(refreshAfterRotate),
                                               name: .UIDeviceOrientationDidChange, object: nil)
        setUpMiscUI()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if let isFirst = UserDefaults.standard.value(forKey: Constants.firstViewing) as? Bool {
            isInitialFirstViewing = isFirst
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        gradientManager.cycleGradient()
        if isInitialFirstViewing && stateManager.currentState == .readyToPlay {
                showFeatureTour()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.statusBarStyle = .lightContent
        setNeedsStatusBarAppearanceUpdate()
        audioPlot.backgroundColor = .clear
        navigationController?.navigationBar.backgroundColor = .clear
        updateRecordingInfo()
    }

    // MARK: IBActions

    @IBAction func discardDidTouch(_ sender: UIButton) {
        confirmAndDiscard()
    }

    @IBAction func shareButtonTapped(_ sender: UIButton) {
        showShareAlertSheet()
    }

    @IBAction func saveButtonDidTouch(_ sender: UIButton) {
        stateManager.endRecording()
    }

    @IBAction func playPauseDidTouch(_ sender: UIButton) {
        stateManager.togglePlayState(sender: sender)
    }

    @IBAction func skipBackDidTouch(_ sender: UIButton) {

        mediaManager.skipFixedTime(time: -reverseSkipValue)
        if timer == nil {
            updateTimerDependentUI()
        }
    }

    @IBAction func sliderDidSlide(_ sender: UISlider) {
        let value = Double(sender.value)
        mediaManager.skipTo(timeInterval: value)
        if timer == nil {
            updateTimerDependentUI()
        }
    }

    @IBAction func skipForwardDidTouch(_ sender: UIButton) {
        mediaManager.skipFixedTime(time: forwardSkipValue)
        if timer == nil {
            updateTimerDependentUI()
        }
    }

    @IBAction func recordButtonDidTouch(_ sender: UIButton) {
        stateManager.toggleRecordingState(sender: sender)
    }

    @IBAction func addDidTouch(_ sender: Any) {
        mediaManager.switchToRecord()
    }
    
    @IBAction func addButtonDidTouch(_ sender: UIButton) {
        if stateManager.allowsAnnotation() {
            showBookmarkModal(sender: sender)
        }
    }

    // MARK: UI Funcs
    private func setUpMiscUI() {

        playStackLeading =
            playStackView.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 5.0)
        playStackTrailing =
            playStackView.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: -5.0)
        playStackView.trailingAnchor.constraint(equalTo: recordStackView.leadingAnchor,
                                                constant: -30.0).isActive = true
        let navBarAttributes = [
            NSAttributedStringKey.foregroundColor: UIColor.white,
            NSAttributedStringKey.font: UIFont(name: Constants.titleFont, size: 18)!]
        navigationController?.navigationBar.titleTextAttributes = navBarAttributes

        createPlaybackLine()
        roundedTopCornerMask(view: addButtonSuperview, size: 40.0)

        addButtonSuperview.clipsToBounds = false

        addBookmarkButton.layer.cornerRadius = Constants.cornerRadius
        addBookmarkButton.layer.borderColor = Constants.textColor.cgColor
        addBookmarkButton.layer.borderWidth = Constants.onePixel
        addBookmarkButton.isEnabled = false
        shareButton.imageView?.contentMode = .scaleAspectFit

        scrubSlider.isContinuous = false

        gradientView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gradientManager.addManagedView(gradientView)
        let backGestureRecognizer: UIGestureRecognizer
        let forwardGestureRecognizer: UIGestureRecognizer
        if self.traitCollection.forceTouchCapability == .available {
            backGestureRecognizer = DeepPressGestureRecognizer(target: self,
                                                               action: #selector(longOrDeepHandler),
                                                               threshold: 0.75)
            forwardGestureRecognizer = DeepPressGestureRecognizer(target: self,
                                                                  action: #selector(longOrDeepHandler),
                                                                  threshold: 0.75)
        } else {
            backGestureRecognizer = UILongPressGestureRecognizer(target: self,
                                                                 action: #selector(longOrDeepHandler))
            forwardGestureRecognizer = UILongPressGestureRecognizer(target: self,
                                                                    action: #selector(longOrDeepHandler))
        }
        skipBackButton.addGestureRecognizer(backGestureRecognizer)
        skipForwardButton.addGestureRecognizer(forwardGestureRecognizer)

        let panGestureRecognizer = UIPanGestureRecognizer(target: self,
                                                          action: #selector(waveformDidPan))
        waveformView.addGestureRecognizer(panGestureRecognizer)
    }

    private func createPlaybackLine() {
        playbackLine = UIView()
        waveformView.addSubview(playbackLine!)
        playbackLine?.backgroundColor = .white
        playbackLine?.widthAnchor.constraint(equalToConstant: Constants.playbackLineWidth).isActive = true // swiftlint:disable:this line_length
        playbackLine?.topAnchor.constraint(equalTo: waveformView.topAnchor,
                                           constant: Constants.insetConstant).isActive = true
        playbackLine?.bottomAnchor.constraint(equalTo: waveformView.bottomAnchor,
                                              constant: -Constants.insetConstant).isActive = true
        playbackLineCenter = playbackLine?.centerXAnchor.constraint(equalTo: waveformView.leadingAnchor, constant: 0) // swiftlint:disable:this line_length
        playbackLineCenter?.isActive = true
        playbackLine?.translatesAutoresizingMaskIntoConstraints = false
        playbackLine?.isHidden = false
    }

    private func confirmAndDiscard() {
        confirmDestructiveAlert(title: AlertConstants.discard,
                                message: AlertConstants.areYouSure) { [weak self] in
            self?.mediaManager.setBlankRecording()
            self?.stateManager.currentState = .prepareToRecord
        }
    }
  
  
    private func showFeatureTour() {
        let highlightController = MDCFeatureHighlightViewController(highlightedView: skipForwardButton, completion: nil)
        highlightController.titleText = "Skip speed"
        highlightController.bodyText = "Force press (or long press) to select 5, 10 or 30 second skips."
        if gradientManager.currentUIColors.count > 1 {
            highlightController.outerHighlightColor = gradientManager.currentUIColors[0]
            highlightController.innerHighlightColor = gradientManager.currentUIColors[1]
            highlightController.titleColor = .white
            highlightController.bodyColor = .white
        }
        
        present(highlightController, animated: true) {
            UserDefaults.standard.set(false, forKey: Constants.firstViewing)
        }
    }

    private func showShareAlertSheet() {
        let alert = UIAlertController(title: AlertConstants.export,
                                      message: nil,
                                      preferredStyle: .actionSheet)
        let bookmarks = UIAlertAction(title: AlertConstants.bookmarks,
                                      style: .default) { [weak self] _ in
            self?.exportBookmarks()
        }
        let recording = UIAlertAction(title: AlertConstants.recording,
                                      style: .default) { [weak self] _ in
            self?.exportRecording()
        }
        let cancel = UIAlertAction(title: AlertConstants.cancel, style: .cancel, handler: nil)
        alert.addAction(bookmarks)
        alert.addAction(recording)
        alert.addAction(cancel)
        present(alert, animated: true, completion: nil)
    }

    private func exportRecording() {
        guard let currentRecording = mediaManager.currentRecording else { return }

        let fileName = currentRecording.fileName
        let userName = "\(currentRecording.userTitle).m4a"
        let originPath = mediaManager.getDocumentsDirectory().appendingPathComponent(fileName)
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent(userName)
        try? FileManager.default.copyItem(at: originPath, to: tempPath)
        let activityController = UIActivityViewController(activityItems: [tempPath],
                                                          applicationActivities: nil)
        activityController.completionWithItemsHandler = {
            _, success, _, _ in
            Analytics.logEvent(AnalyticsConstants.objectExported, parameters: [
                AnalyticsConstants.typeExported: userName,
                AnalyticsConstants.exportSuccess: success,
                AnalyticsConstants.recordingID: currentRecording.fileName,
                AnalyticsConstants.numberOfBookmarks: currentRecording.annotations?.count ?? 0,
                AnalyticsConstants.recordingDuration: currentRecording.duration
            ])
            }
        present(activityController, animated: true, completion: nil)
    }

    private func exportBookmarks() {
        guard let currentRecording = mediaManager.currentRecording else { return }
        if let stringURL = AnnotatedRecording.formatBookmarksForExport(recording: currentRecording) {
            let activityController = UIActivityViewController(activityItems: [stringURL],
                                                              applicationActivities: nil)
            activityController.completionWithItemsHandler = {
                _, success, _, _ in
                Analytics.logEvent(AnalyticsConstants.objectExported, parameters: [
                    AnalyticsConstants.typeExported: "Bookmarks",
                    AnalyticsConstants.exportSuccess: success,
                    AnalyticsConstants.recordingID: currentRecording.fileName,
                    AnalyticsConstants.numberOfBookmarks: currentRecording.annotations?.count ?? 0,
                    AnalyticsConstants.recordingDuration: currentRecording.duration
                ])
            }
            present(activityController, animated: true, completion: nil)
        }
    }

    private func toggleSlider(isOn: Bool) {
        if isOn {
            scrubSlider.setThumbImage(UIImage(named: ImageConstants.thumbImage), for: .normal)
            scrubSlider.isEnabled = true
            setSliderImages()
        } else {
            scrubSlider.minimumValueImage = nil
            scrubSlider.maximumValueImage = nil
            scrubSlider.setThumbImage(UIImage(), for: .disabled)
            scrubSlider.setValue(0, animated: false)
            scrubSlider.isEnabled = false
        }
    }

    private func setSliderImages() {
        guard let duration = mediaManager.currentRecording?.duration else { return }
        scrubSlider.minimumValue = 0.0
        scrubSlider.maximumValue = Float(duration)
        let timeString = String.shortStringFrom(timeInterval: duration)
        let image = UIImage.imageFromString(string: timeString)
        let zeroImage = UIImage.imageFromString(string: Constants.zeroString)
        scrubSlider.maximumValueImage = image
        scrubSlider.minimumValueImage = zeroImage
    }

    private func toggleBookmarkButton(active: Bool) {
        UIView.animate(withDuration: 0.33,
                       delay: 0.0,
                       options: .curveEaseOut,
                       animations: { [weak self] in
                        self?.addBookmarkButton.isEnabled = active
                        self?.addBookmarkButton.layer.opacity = active ? 1.0 : 0.25
        }, completion: nil)
    }
    
    @objc
    private func waveformDidPan(sender: UIPanGestureRecognizer) {
        guard stateManager.isPlayMode else { return }
        guard let end = mediaManager.currentRecording?.duration else { return } // swiftlint:disable:this identifier_name
        let offset = sender.location(in: waveformView).x
        let seconds = end / Double(waveformView.bounds.maxX / offset)
        let skipTime = seconds - mediaManager.currentTimeInterval
        mediaManager.skipFixedTime(time: skipTime)
        if timer == nil {
            updateTimerDependentUI()
        }
    }

    private func movePlaybackLine(value: Double) {
        let waveformViewMax = Float(waveformView.bounds.maxX)
        let maxSeconds = scrubSlider.maximumValue
        let offset: Float
        if value > 0 && value.isFinite {
            offset = waveformViewMax / (maxSeconds / Float(value))
        } else {
            offset = 0
        }
        playbackLineCenter?.constant = CGFloat(offset)
    }

    @objc
    private func refreshAfterRotate() {
        let orientation = UIDevice.current.orientation
        if orientation.isLandscape || orientation.isPortrait {
            roundedTopCornerMask(view: addButtonSuperview, size: 40.0)
            toggleBookmarkButton(active: stateManager.allowsAnnotation())
            gradientManager.redrawGradients()
        }
    }

    private func roundedTopCornerMask(view: UIView, size: Double ) {
        let cornerRadius = CGSize(width: size, height: size)
        let maskPath = UIBezierPath(roundedRect: view.bounds,
                                    byRoundingCorners: [.topLeft, .topRight],
                                    cornerRadii: cornerRadius)
        let shape = CAShapeLayer()
        shape.path = maskPath.cgPath
        view.layer.mask = shape
    }

    @objc
    private func longOrDeepHandler(sender: UIGestureRecognizer) {
        guard let skipVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: Constants.skipVC) as? SkipViewController else { return } // swiftlint:disable:this line_length
        skipVC.modalPresentationStyle = .popover
        skipVC.delegate = self

        if let popoverController = skipVC.popoverPresentationController,
            let view = sender.view {
            popoverController.delegate = self
            popoverController.sourceView = view
            popoverController.sourceRect = view.bounds
            popoverController.permittedArrowDirections = .down
             
            skipVC.preferredContentSize = CGSize(width: view.bounds.width / 2, height: Constants.skipVCHeight)
        }

        if sender.view?.tag == 0 { // Rewind View
            skipVC.mode = .reverse
        } else { // Forward View
            skipVC.mode = .forward
        }
        present(skipVC, animated: true, completion: nil)
    }

    @objc
    func showBookmarkModal(sender: Any) {
        guard let bookmarkVC =
            UIStoryboard(name: mainStoryboard,
                         bundle: nil).instantiateViewController(withIdentifier: bookmarkModal)
                as? BookmarkModalViewController else { return }
        bookmarkVC.modalPresentationStyle = .custom
        bookmarkVC.transitioningDelegate = modalTransitioningDelegate

        if sender is UIButton {
            bookmarkVC.bookmarkType = .create
        }

        if let sender = sender as? UILongPressGestureRecognizer,
            let tableviewCell = sender.view as? BookmarkTableViewCell {
            bookmarkVC.bookmarkType = .edit
            bookmarkVC.currentBookmarkIndexPath = tableviewCell.indexPath
        }
        present(bookmarkVC, animated: true, completion: nil)
    }

    @objc
    private func toggleTimer(isOn: Bool) {
        if isOn {
            timer = Timer.scheduledTimer(timeInterval: Constants.timerInterval,
                                         target: self, selector: #selector(self.updateTimerDependentUI),
                                         userInfo: nil, repeats: true)
            let runLoop = RunLoop.current
            runLoop.add(timer!, forMode: .UITrackingRunLoopMode)
        } else {
            timer?.invalidate()
            timer = nil
        }
    }
    
    @objc
    private func updateTimerDependentUI() {
        stopWatchLabel.text = mediaManager.stopWatchTimeString ?? Constants.emptyTimeString
        if scrubSlider.isEnabled && !scrubSlider.isTracking {
            let value = mediaManager.currentTimeInterval
            scrubSlider.setValue(Float(value), animated: false)
            movePlaybackLine(value: value)
        }
    }
    
    @objc
    private func updateTableView() {
        annotationTableView.reloadData()
    }

    @objc
    private func updateRecordingInfo() {
        if let currentRecording = mediaManager.currentRecording {
            self.title = currentRecording.userTitle
            stopWatchLabel.text = String.stopwatchStringFrom(timeInterval: currentRecording.duration)
            updateTableView()
        }
    }

    private func resetPlot() {
        summaryPlot?.removeFromSuperview()
        livePlot?.clear()
        livePlot?.plotType = .rolling
        livePlot?.shouldFill = true
        livePlot?.shouldMirror = true
        livePlot?.backgroundColor = .clear
        livePlot?.color = .white
        livePlot?.gain = 2
        livePlot?.setRollingHistoryLength(200)
    }

    private func setSummaryPlot() {
        summaryPlot?.removeFromSuperview()
        summaryPlot = mediaManager.getPlotFromCurrentRecording()
        audioPlot.addSubview(summaryPlot!)
        // Setting the frame or bounds causes misalignment upon rotation
        // Use autolayout constraints instead
        summaryPlot?.translatesAutoresizingMaskIntoConstraints = false
        summaryPlot?.topAnchor.constraint(equalTo: waveformView.topAnchor).isActive = true
        summaryPlot?.bottomAnchor.constraint(equalTo: waveformView.bottomAnchor).isActive = true
        // Need to inset the view because the border drawing view draws its border inset dx 3.0 dy 3.0
        // and has a border width of 2.0. 4.0 has a nice seamless look
                summaryPlot?.leadingAnchor.constraint(equalTo: waveformView.leadingAnchor,
                                                      constant: Constants.insetConstant).isActive = true
        let trailing = waveformView.bounds.width * Constants.trailingInset
        summaryPlot?.trailingAnchor.constraint(equalTo: waveformView.trailingAnchor,
                                               constant: -trailing).isActive = true

    }
    
    private func setUpAudioPlot() {
        livePlot = AKNodeOutputPlot(microphone, frame: CGRect())
        livePlot?.plotType = .rolling
        livePlot?.shouldFill = true
        livePlot?.shouldMirror = true
        livePlot?.backgroundColor = .clear
        livePlot?.color = .white
        livePlot?.gain = 3
        livePlot?.setRollingHistoryLength(200) // 200 Displays 5 sec before scrolling
        audioPlot.addSubview(livePlot!)
        livePlot?.translatesAutoresizingMaskIntoConstraints = false
        livePlot?.topAnchor.constraint(equalTo: waveformView.topAnchor).isActive = true
        livePlot?.bottomAnchor.constraint(equalTo: waveformView.bottomAnchor).isActive = true
        // Need to inset the view because the border drawing view draws its border inset dx 3.0 dy 3.0
        // and has a border width of 2.0. 4.0 has a nice seamless look
        livePlot?.leadingAnchor.constraint(equalTo: waveformView.leadingAnchor,
                                           constant: Constants.insetConstant).isActive = true
        let trailing = waveformView.bounds.width * Constants.trailingInset
        livePlot?.trailingAnchor.constraint(equalTo: waveformView.trailingAnchor,
                                            constant: -trailing).isActive = true
    }

    private func switchToPlayStack() {
        guard let playStackLeading = playStackLeading,
            let playStackTrailing = playStackTrailing else { return }
        NSLayoutConstraint.deactivate([recordStackLeading, recordStackTrailing])
        NSLayoutConstraint.activate([playStackLeading, playStackTrailing])
        UIView.animate(withDuration: 0.33, delay: 0, options: .curveEaseInOut, animations: {
            self.view.layoutIfNeeded()
        })
    }

    private func switchToRecordStack() {
        guard let playStackLeading = playStackLeading,
            let playStackTrailing = playStackTrailing else { return }
            NSLayoutConstraint.deactivate([playStackLeading, playStackTrailing])
            NSLayoutConstraint.activate([recordStackLeading, recordStackTrailing])
        UIView.animate(withDuration: 0.33, delay: 0, options: .curveEaseInOut, animations: {
            self.view.layoutIfNeeded()
        })
    }
}

extension AudioRecordViewController: StateManagerViewDelegate {

    func updateButtons() {
        if stateManager.isRecordMode {
            playbackLineCenter?.constant = 0.0
        }
        self.shareButton.isHidden = !self.stateManager.canShare
        UIView.animate(withDuration: 0.33, delay: 0, options: .curveEaseInOut, animations: {
            self.view.layoutIfNeeded()
        })
        toggleBookmarkButton(active: stateManager.canAnnotate)
        playbackLine?.isHidden = stateManager.isRecordMode
        playPauseButton.isSelected = stateManager.isPlaying
        plusButton.isEnabled = stateManager.isPlayMode
        filesButton.isEnabled = stateManager.canViewFiles
        discardButton.isEnabled = stateManager.canDiscard
        recordButton.isSelected = stateManager.isRecording
    }

    func errorAlert(_ error: Error) {
        // TODO: Implement this so it can show errors from the state manager
    }

    func finishRecording() {
        updateButtons()
        updateRecordingInfo()
        livePlot?.clear()
        toggleSlider(isOn: false)
    }

    func startRecording() {
        try? AudioKit.start()
        updateButtons()
        toggleTimer(isOn: true)
    }

    func prepareToPlay() {
        updateButtons()
        scrubSlider.value = 0.0
        movePlaybackLine(value: 0.0)
        updateRecordingInfo()
        livePlot?.clear()
        setSummaryPlot()
        toggleSlider(isOn: true)
        switchToPlayStack()
    }

    func initialSetup() {
        updateRecordingInfo()
        setUpAudioPlot()
        toggleSlider(isOn: false)
        switchToRecordStack()
    }

    func prepareToRecord() {
        updateRecordingInfo()
        updateButtons()
        resetPlot()
        toggleSlider(isOn: false)
        switchToRecordStack()
    }

    func playAudio() {
        toggleTimer(isOn: true)
        updateButtons()
    }

    func pauseRecording() {
        DispatchQueue.main.async {
             try? AudioKit.stop()
        }
        toggleTimer(isOn: false)
        updateButtons()
    }

    func resumeRecording() {
        updateButtons()
        try? AudioKit.start()
        toggleTimer(isOn: true)
    }

    func stopRecording() {
        toggleTimer(isOn: false)
        self.presentAlertWith(title: AlertConstants.save,
                              message: AlertConstants.enterTitle,
                              placeholder: AlertConstants.newRecording) { [ weak self ] name in
                                if name != "" {
                                    self?.mediaManager.currentRecording?.userTitle = name
                                }
                                self?.mediaManager.stopRecordingAudio()
                                self?.presentAlert(title: AlertConstants.success,
                                                   message: AlertConstants.recordingSaved)
                                self?.updateRecordingInfo()
        }
    }
}

extension AudioRecordViewController: BookmarkTableViewDelegate, UITableViewDataSource, UITableViewDelegate {

    func updateBookmarkTableview() {
        annotationTableView.reloadData()
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCellEditingStyle,
                   forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            mediaManager.currentRecording?.annotations!.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70.0
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        let count = mediaManager.currentRecording?.annotations?.count ?? 0

        if count == 0 && tableView.backgroundView == nil {
            tableView.isScrollEnabled = false

            let view = UIView(frame:CGRect())
            let label = UILabel(frame: CGRect())
            label.text = Constants.emptyTableText
            label.font = UIFont(name: "OpenSans-Light", size: 16.0)
            label.textColor = Constants.placeholderColor
            label.textAlignment = .center
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            view.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            label.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            tableView.backgroundView = view
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: tableView.widthAnchor,
                                        constant: -Constants.tableViewInset * 2).isActive = true
            view.leadingAnchor.constraint(equalTo: tableView.leadingAnchor,
                                          constant: Constants.tableViewInset).isActive = true
            view.trailingAnchor.constraint(equalTo: tableView.trailingAnchor,
                                           constant: -Constants.tableViewInset).isActive = true
            view.topAnchor.constraint(equalTo: tableView.topAnchor,
                                      constant: Constants.tableViewInset).isActive = true
            view.bottomAnchor.constraint(equalTo: tableView.topAnchor,
                                         constant: Constants.viewSize).isActive = true
            return 1
        }
        if count > 0 {
            tableView.isScrollEnabled = true
            tableView.backgroundView = nil
            return 1
        }
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return mediaManager.currentRecording?.annotations?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) ->
        UITableViewCell {
            guard indexPath.row < (mediaManager.currentRecording?.annotations?.count)!
                else { fatalError("Index row exceeds array bounds") }

            if let cell = tableView.dequeueReusableCell(withIdentifier: Constants.cellIdentifier)
                as? BookmarkTableViewCell,
                let bookmark = mediaManager.currentRecording?.annotations?[indexPath.row] {

                cell.populateFromBookmark(bookmark, index: indexPath)

                if cell.longPressRecognizer == nil {
                    cell.longPressRecognizer = UILongPressGestureRecognizer()
                }
                cell.longPressRecognizer.addTarget(self, action: #selector(showBookmarkModal))
                cell.addGestureRecognizer(cell.longPressRecognizer)
                return cell
            }
            return tableView.dequeueReusableCell(withIdentifier: Constants.cellIdentifier)!
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let bookmark = mediaManager.currentRecording?.annotations?[indexPath.row] {

                scrubSlider.setValue(Float(bookmark.timeStamp), animated: false)
                switch stateManager.currentState {
                case .playing, .playingPaused, .playingStopped:
                    mediaManager.skipTo(timeInterval: bookmark.timeStamp)
                case .readyToPlay:
                    mediaManager.playAudio()

                    mediaManager.skipTo(timeInterval: bookmark.timeStamp)
                default:
                    return
            }
            if timer == nil { updateTimerDependentUI() }
        }
    }
}

extension AudioRecordViewController: SkipControllerDelegate {
    func changeSkipValue(_ value: Double, mode: SkipVCMode) {
        switch mode {
        case .forward:
            forwardSkipValue = value
            var image: UIImage?
            switch value {
            case 30:
                image = UIImage(named: ImageConstants.forward30)
            case 10:
                image = UIImage(named: ImageConstants.forward10)
            case 5:
                image = UIImage(named: ImageConstants.forward5)
            default:
                image = UIImage()
            }
            guard let buttonImage = image else { return }
            skipForwardButton.setImage(buttonImage, for: .normal)
        case .reverse:
            reverseSkipValue = value
            var image: UIImage?
            switch value {
            case 30:
                image = UIImage(named: ImageConstants.replay30)
            case 10:
                image = UIImage(named: ImageConstants.replay10)
            case 5:
                image = UIImage(named: ImageConstants.replay5)
            default:
                image = UIImage()
            }
            guard let buttonImage = image else { return }
            skipBackButton.setImage(buttonImage, for: .normal)
        }
    }
}

extension AudioRecordViewController: UIPopoverPresentationControllerDelegate {

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
} // swiftlint:disable:this file_length
