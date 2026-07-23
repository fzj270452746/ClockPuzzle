//
//  LevelSelectViewController.swift
//  Clock
//
//  关卡选择：按章节分区的关卡网格。已解锁关可点，未解锁置灰锁定；
//  已通关关显示星级。数据来自 SaveStore，章节信息与 BuiltinLevels 一致。
//

import UIKit

final class LevelSelectViewController: UIViewController,
                                       UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    var onPick: ((Int) -> Void)?
    var onBack: (() -> Void)?

    private let saveStore: SaveStore
    private var collection: UICollectionView!

    // 章节分区（名称 + 关卡范围），与 BuiltinLevels.chapters 对应。
    private let chapters: [(name: String, range: ClosedRange<Int>)] = [
        ("Clock Workshop",   1...20),
        ("Pendulum Hall",    21...50),
        ("Gear Castle",      51...90),
        ("Mechanical Tower", 91...140),
        ("Dragon Clock",     141...200),
    ]

    init(saveStore: SaveStore) {
        self.saveStore = saveStore
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        Theme.applyBackground(to: view)
        buildHeader()
        buildCollection()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        Theme.resizeBackground(in: view)
    }

    private func buildHeader() {
        let back = Theme.makeButton("‹ Back", kind: .ghost) { [weak self] in self?.onBack?() }
        back.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(back)

        let title = UILabel()
        title.text = "SELECT LEVEL"
        title.font = Theme.title(22)
        title.textColor = Theme.ivory
        title.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(title)

        NSLayoutConstraint.activate([
            back.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            back.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: back.centerYAnchor),
        ])
    }

    private func buildCollection() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 24, right: 16)
        layout.headerReferenceSize = CGSize(width: view.bounds.width, height: 44)

        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.dataSource = self
        collection.delegate = self
        collection.register(LevelCell.self, forCellWithReuseIdentifier: LevelCell.reuseId)
        collection.register(ChapterHeader.self,
                            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                            withReuseIdentifier: ChapterHeader.reuseId)
        collection.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collection)

        NSLayoutConstraint.activate([
            collection.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            collection.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collection.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collection.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - DataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int { chapters.count }

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        chapters[section].range.count
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: LevelCell.reuseId, for: indexPath) as! LevelCell
        let id = levelId(at: indexPath)
        cell.configure(id: id,
                       unlocked: saveStore.isUnlocked(id),
                       record: saveStore.record(for: id))
        return cell
    }

    func collectionView(_ cv: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        let header = cv.dequeueReusableSupplementaryView(ofKind: kind,
                        withReuseIdentifier: ChapterHeader.reuseId, for: indexPath) as! ChapterHeader
        let ch = chapters[indexPath.section]
        let cleared = ch.range.filter { saveStore.record(for: $0)?.cleared == true }.count
        header.configure(title: ch.name, progress: "\(cleared)/\(ch.range.count)")
        return header
    }

    // MARK: - Delegate

    func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        // 每行 5 个。
        let columns: CGFloat = 5
        let spacing: CGFloat = 12
        let inset: CGFloat = 16
        let available = cv.bounds.width - inset * 2 - spacing * (columns - 1)
        let side = floor(available / columns)
        return CGSize(width: side, height: side)
    }

    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let id = levelId(at: indexPath)
        guard saveStore.isUnlocked(id) else { return }
        onPick?(id)
    }

    private func levelId(at indexPath: IndexPath) -> Int {
        chapters[indexPath.section].range.lowerBound + indexPath.item
    }
}
