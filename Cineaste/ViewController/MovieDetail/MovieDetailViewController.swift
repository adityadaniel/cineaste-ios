//
//  MovieDetailViewController.swift
//  Cineaste
//
//  Created by Christian Braun on 04.11.17.
//  Copyright © 2017 notimeforthat.org. All rights reserved.
//

import UIKit
import CoreData

class MovieDetailViewController: UIViewController {
    @IBOutlet weak fileprivate var posterImageView: UIImageView!
    @IBOutlet weak fileprivate var titleLabel: TitleLabel!

    @IBOutlet var descriptionLabels: [DescriptionLabel]! {
        didSet {
            for label in descriptionLabels {
                label.textColor = UIColor.basicBackground
            }
        }
    }
    @IBOutlet weak fileprivate var releaseDateLabel: DescriptionLabel!
    @IBOutlet weak fileprivate var runtimeLabel: DescriptionLabel!
    @IBOutlet weak fileprivate var votingLabel: DescriptionLabel! {
        didSet {
            votingLabel.textColor = UIColor.black
        }
    }

    @IBOutlet weak fileprivate var seenButton: ActionButton! {
        didSet {
            self.seenButton.setTitle(Strings.seenButton, for: .normal)
        }
    }
    @IBOutlet weak fileprivate var mustSeeButton: ActionButton! {
        didSet {
            self.mustSeeButton.setTitle(Strings.mustSeeButton, for: .normal)
        }
    }
    @IBOutlet var deleteButton: ActionButton! {
        didSet {
            self.deleteButton.setTitle(Strings.deleteButton, for: .normal)
        }
    }

    @IBOutlet weak fileprivate var descriptionTextView: UITextView! {
        didSet {
            descriptionTextView.isEditable = false
        }
    }

    var type: MovieDetailType = .search

    private func updateDetail(for type: MovieDetailType) {
        switch type {
        case .seen:
            mustSeeButton.isHidden = false
            seenButton.isHidden = true
            deleteButton.isHidden = false
        case .wantToSee:
            mustSeeButton.isHidden = true
            seenButton.isHidden = false
            deleteButton.isHidden = false
        case .search:
            mustSeeButton.isHidden = false
            seenButton.isHidden = false
            deleteButton.isHidden = true
        }
    }

    var storageManager: MovieStorage?

    var movie: Movie? {
        didSet {
            if let movie = movie {
                loadDetails(for: movie)
            }
        }
    }

    var storedMovie: StoredMovie? {
        didSet {
            if let movie = storedMovie {
                setupUI(for: movie)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Actions

    @IBAction func mustSeeButtonTouched(_ sender: UIButton) {
        saveMovie(withWatched: false)
    }

    @IBAction func seenButtonTouched(_ sender: UIButton) {
        saveMovie(withWatched: true)
    }

    @IBAction func deleteButtonTouched(_ sender: UIButton) {
        deleteMovie()
    }

    // MARK: - Private

    fileprivate func saveMovie(withWatched watched: Bool) {
        guard let storageManager = storageManager else { return }

        if let movie = movie {
            storageManager.insertMovieItem(with: movie, watched: watched) { result in
                switch result {
                case .error:
                    DispatchQueue.main.async {
                        self.showAlert(withMessage: Alert.insertMovieError)
                    }
                case .success:
                    DispatchQueue.main.async {
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            }
        } else if let storedMovie = storedMovie {
            storageManager.updateMovieItem(with: storedMovie, watched: watched) { result in
                switch result {
                case .error:
                    DispatchQueue.main.async {
                        self.showAlert(withMessage: Alert.updateMovieError)
                    }
                case .success:
                    DispatchQueue.main.async {
                        self.navigationController?.popViewController(animated: true)
                    }
                }
            }
        }
    }

    fileprivate func deleteMovie() {
        guard let storageManager = storageManager else { return }

        if let storedMovie = storedMovie {
            storageManager.remove(storedMovie, handler: { result in
                guard case .success = result else {
                    self.showAlert(withMessage: Alert.deleteMovieError)
                    return
                }

                DispatchQueue.main.async {
                    self.navigationController?.popViewController(animated: true)
                }
            })
        }
    }

    fileprivate func loadDetails(for movie: Movie) {
        // Setup with the default data to show something while new data is loading
        self.setupUI(for: movie)

        Webservice.load(resource: movie.get) { result in
            guard case let .success(detailedMovie) = result else { return }

            detailedMovie.poster = movie.poster
            self.movie = detailedMovie
            self.setupUI(for: detailedMovie)
        }
    }

    fileprivate func setupUI(for networkMovie: Movie) {
        DispatchQueue.main.async {
            if let moviePoster = networkMovie.poster {
                self.posterImageView.image = moviePoster
            }
            self.titleLabel.text = networkMovie.title
            self.descriptionTextView.text = networkMovie.overview
            self.runtimeLabel.text = "\(networkMovie.runtime) min"
            self.votingLabel.text = "\(networkMovie.voteAverage)"
            self.releaseDateLabel.text = networkMovie.releaseDate.formatted
        }
    }

    fileprivate func setupUI(for localMovie: StoredMovie) {
        DispatchQueue.main.async {
            if let moviePoster = localMovie.poster {
                self.posterImageView.image = UIImage(data: moviePoster)
            }
            self.titleLabel.text = localMovie.title
            self.descriptionTextView.text = localMovie.overview
            self.runtimeLabel.text = "\(localMovie.runtime) min"
            self.votingLabel.text = "\(localMovie.voteAverage)"
            self.releaseDateLabel.text = localMovie.releaseDate?.formatted
        }
    }

    // MARK: 3D Actions

    override var previewActionItems: [UIPreviewActionItem] {
        let addToWatchListAction = UIPreviewAction(title: "Muss ich sehen", style: .default) { (_, _) -> Void in
            self.saveMovie(withWatched: false)
        }

        let addToWatchedListAction = UIPreviewAction(title: "Schon gesehen", style: .default) { (_, _) -> Void in
            self.saveMovie(withWatched: true)
        }

        let deleteMovieAction = UIPreviewAction(title: "Von Liste löschen", style: .destructive) { (_, _) -> Void in
            self.deleteMovie()
        }

        if type == .search {
            return [addToWatchListAction, addToWatchedListAction]
        } else {
            return [addToWatchListAction, addToWatchedListAction, deleteMovieAction]
        }

    }
}

extension MovieDetailViewController: Instantiable {
    static var storyboard: Storyboard { return .movieDetail }
    static var storyboardID: String? { return "MovieDetailViewController" }
}
