//
//  MoviesViewController.swift
//  Cineaste
//
//  Created by Felizia Bernutz on 01.01.18.
//  Copyright © 2018 notimeforthat.org. All rights reserved.
//

import UIKit
import CoreData

class MoviesViewController: UIViewController {
    var category: MovieListCategory = .wantToSee {
        didSet {
            title = category.title
            emptyListLabel.text = String.title(for: category)

            //only update if category changed
            guard oldValue != category else { return }
            if fetchedResultsManager.controller == nil {
                fetchedResultsManager.setup(with: category.predicate) {
                    self.myMoviesTableView.reloadData()
                }
            } else {
                fetchedResultsManager.refetch(for: category.predicate) {
                    self.myMoviesTableView.reloadData()
                }
            }
        }
    }

    lazy var resultSearchController: SearchController = {
        let resultSearchController = SearchController(searchResultsController: nil)
        resultSearchController.searchResultsUpdater = self
        return resultSearchController
    }()

    @IBOutlet var emptyView: UIView!
    @IBOutlet var emptyListLabel: TitleLabel! {
        didSet {
            emptyListLabel.textColor = UIColor.basicWhite
        }
    }
    @IBOutlet var myMoviesTableView: UITableView! {
        didSet {
            myMoviesTableView.dataSource = self
            myMoviesTableView.delegate = self

            myMoviesTableView.tableFooterView = UIView()
            myMoviesTableView.backgroundColor = UIColor.basicBackground

            myMoviesTableView.rowHeight = UITableViewAutomaticDimension
            myMoviesTableView.estimatedRowHeight = 80

            myMoviesTableView.backgroundView = emptyView
        }
    }

    let fetchedResultsManager = FetchedResultsManager()
    var storageManager: MovieStorage?
    var selectedMovie: StoredMovie?
    fileprivate var saveAction: UIAlertAction?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.basicBackground

        fetchedResultsManager.delegate = self
        fetchedResultsManager.setup(with: category.predicate) {
            self.myMoviesTableView.reloadData()
            self.showEmptyState(self.fetchedResultsManager.controller?.fetchedObjects?.isEmpty)
        }

        registerForPreviewing(with: self, sourceView: myMoviesTableView)

        configureSearchController()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let indexPath = myMoviesTableView.indexPathForSelectedRow {
            myMoviesTableView.deselectRow(at: indexPath, animated: true)
        }
    }

    // MARK: - SearchController

    func configureSearchController() {
        if #available(iOS 11.0, *) {
            navigationItem.searchController = resultSearchController
            navigationItem.hidesSearchBarWhenScrolling = true
        } else {
            myMoviesTableView.tableHeaderView = resultSearchController.searchBar
        }

        definesPresentationContext = true
    }

    override func viewDidLayoutSubviews() {
        super.viewWillLayoutSubviews()

        if #available(iOS 11.0, *) {
            return
        } else {
            resultSearchController.searchBar.sizeToFit()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        showEmptyState(fetchedResultsManager.controller?.fetchedObjects?.isEmpty)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        fetchedResultsManager.refetch(for: category.predicate) {
            self.resultSearchController.isActive = false
        }
    }

    // MARK: - Action

    @IBAction func movieNightButtonTouched(_ sender: UIBarButtonItem) {
        if UserDefaultsManager.getUsername() == nil {
            showUsernameAlert()
        } else {
            performSegue(withIdentifier: Segue.showMovieNight.rawValue, sender: nil)
        }
    }

    @IBAction func triggerSearchMovieAction(_ sender: UIBarButtonItem) {
        perform(segue: .showSearchFromMovieList, sender: self)
    }

    func showEmptyState(_ isEmpty: Bool?, handler: (() -> Void)? = nil) {
        let isEmpty = isEmpty ?? true

        DispatchQueue.main.async {
            UIView.animate(
                withDuration: 0.2,
                animations: {
                    self.myMoviesTableView.backgroundView?.alpha = isEmpty ? 1 : 0
                },
                completion: { _ in
                    self.myMoviesTableView.backgroundView?.isHidden = !isEmpty
                    handler?()
                })
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch Segue(initWith: segue) {
        case .showSearchFromMovieList?:
            let navigationVC = segue.destination as? UINavigationController
            let vc = navigationVC?.viewControllers.first as? SearchMoviesViewController
            vc?.storageManager = storageManager
        case .showMovieDetail?:
            let vc = segue.destination as? MovieDetailViewController
            vc?.storedMovie = selectedMovie
            vc?.storageManager = storageManager
            vc?.type = (category == MovieListCategory.seen) ? .seen : .wantToSee
        case .showMovieNight?:
            let navigationVC = segue.destination as? UINavigationController
            let vc = navigationVC?.viewControllers.first as? MovieNightViewController
            vc?.storageManager = storageManager
        default:
            break
        }
    }

    func showUsernameAlert() {
        let alert = UIAlertController(title: Alert.insertUsername.title,
                                      message: Alert.insertUsername.message,
                                      preferredStyle: .alert)
        saveAction = UIAlertAction(title: Alert.insertUsername.action, style: .default) { _ in
            guard let textField = alert.textFields?[0], let username = textField.text else {
                return
            }
            UserDefaultsManager.setUsername(username)
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: Segue.showMovieNight.rawValue, sender: nil)
            }
        }

        if let saveAction = saveAction {
            saveAction.isEnabled = false
            alert.addAction(saveAction)
        }

        if let cancelTitle = Alert.insertUsername.cancel {
            let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
            alert.addAction(cancelAction)
        }

        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = String.usernamePlaceholder
            textField.delegate = self
        })

        present(alert, animated: true)
    }

    private func updateShortcutItems() {
        guard let movies = self.fetchedResultsManager.controller?.fetchedObjects else {
            return
        }

        var shortcuts = UIApplication.shared.shortcutItems ?? []

        //initially instantiate shortcuts
        if shortcuts.isEmpty {
            let wantToSeeIcon = UIApplicationShortcutIcon(templateImageName: "add_to_watchlist")
            let wantToSeeShortcut =
                UIApplicationShortcutItem(type: ShortcutIdentifier.wantToSeeList.rawValue,
                                          localizedTitle: String.wantToSeeList,
                                          localizedSubtitle: nil,
                                          icon: wantToSeeIcon,
                                          userInfo: nil)

            let seenIcon = UIApplicationShortcutIcon(templateImageName: "add_to_watchedlist")
            let seenShortcut =
                UIApplicationShortcutItem(type: ShortcutIdentifier.seenList.rawValue,
                                          localizedTitle: String.seenList,
                                          localizedSubtitle: nil,
                                          icon: seenIcon,
                                          userInfo: nil)

            shortcuts = [wantToSeeShortcut, seenShortcut]
            UIApplication.shared.shortcutItems = shortcuts
        }

        let index = category == .wantToSee ? 0 : 1
        let existingItem = shortcuts[index]

        //only update if value changed
        let newShortcutSubtitle =
            movies.isEmpty
            ? nil
            : String.movies(for: movies.count)
        if existingItem.localizedSubtitle != newShortcutSubtitle {
            //swiftlint:disable:next force_cast
            let mutableShortcutItem = existingItem.mutableCopy() as! UIMutableApplicationShortcutItem
            mutableShortcutItem.localizedSubtitle = newShortcutSubtitle

            shortcuts[index] = mutableShortcutItem

            UIApplication.shared.shortcutItems = shortcuts
        }
    }
}

// MARK: - UITextFieldDelegate

extension MoviesViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }

        let entryLength = text.count + string.count - range.length
        saveAction?.isEnabled = entryLength > 0 ? true : false

        return true
    }
}

// MARK: - FetchedResultsManagerDelegate

extension MoviesViewController: FetchedResultsManagerDelegate {
    func beginUpdate() {
        myMoviesTableView.beginUpdates()
    }
    func insertRows(at index: [IndexPath]) {
        myMoviesTableView.insertRows(at: index, with: .fade)
    }
    func deleteRows(at index: [IndexPath]) {
        myMoviesTableView.deleteRows(at: index, with: .fade)
    }
    func updateRows(at index: [IndexPath]) {
        myMoviesTableView.reloadRows(at: index, with: .fade)
    }
    func moveRow(at index: IndexPath, to newIndex: IndexPath) {
        myMoviesTableView.moveRow(at: index, to: newIndex)
    }
    func endUpdate() {
        myMoviesTableView.endUpdates()
        showEmptyState(fetchedResultsManager.controller?.fetchedObjects?.isEmpty)
        updateShortcutItems()
    }
}

// MARK: - Instantiable

extension MoviesViewController: Instantiable {
    static var storyboard: Storyboard { return .movieList }
    static var storyboardID: String? { return "MoviesViewController" }
}
