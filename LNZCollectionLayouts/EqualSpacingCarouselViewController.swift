//
//  EqualSpacingCarouselViewController.swift
//  LNZCollectionLayouts
//
//  Created by 周俊 on 2020/5/25.
//  Copyright © 2020 Gilt. All rights reserved.
//

import UIKit

class EqualSpacingCarouselViewController: UIViewController {

    @IBOutlet var equalCollectionView: UICollectionView!
    @IBOutlet var snapCollectionView: UICollectionView!
    lazy var collectionViews: [UICollectionView] = [self.equalCollectionView, self.snapCollectionView]

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

extension EqualSpacingCarouselViewController: UICollectionViewDelegate, UICollectionViewDataSource, UIScrollViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 15
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)

        let label = cell.contentView.viewWithTag(10)! as! UILabel
        cell.layer.borderColor = UIColor.darkGray.cgColor
        cell.layer.borderWidth = 1

        label.text = "\(indexPath.item)"

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == equalCollectionView {
            let layout = collectionView.collectionViewLayout as? LNZEqualSpacingCarouselLayout
            layout?.scrollToItem(at: indexPath)
        } else {
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        print("scrollViewDidScroll : \(scrollView.contentOffset)")
        let another = collectionViews.filter { $0 != scrollView }
        another.first?.contentOffset = scrollView.contentOffset
    }
}
