#import "OVPlaylistViewController.h"
#import "OVMediaItem.h"
#import "OVTheme.h"

@interface OVPlaylistViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) NSArray *items;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) UITableView *tableView;

@end

@implementation OVPlaylistViewController

- (instancetype)initWithItems:(NSArray *)items currentIndex:(NSInteger)currentIndex
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _items = [items copy] ?: @[];
        _currentIndex = currentIndex;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Lista de reproducción";
    self.view.backgroundColor = [OVTheme background];
    [OVTheme styleNavigationBar:self.navigationController.navigationBar];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(dismissSelf)];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                      UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [OVTheme styleTableView:self.tableView];
    [self.view addSubview:self.tableView];
}

- (void)dismissSelf
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"OVPlaylistCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:identifier];
        cell.backgroundColor = [OVTheme background];
        cell.textLabel.textColor = [OVTheme text];
        cell.textLabel.font = [OVTheme font:15.0 weight:UIFontWeightMedium];
        cell.detailTextLabel.textColor = [OVTheme secondaryText];
        cell.detailTextLabel.font = [OVTheme font:12.0 weight:UIFontWeightRegular];
        UIView *selected = [[UIView alloc] initWithFrame:CGRectZero];
        selected.backgroundColor = [OVTheme surfaceLight];
        cell.selectedBackgroundView = selected;
    }

    OVMediaItem *item = self.items[indexPath.row];
    cell.textLabel.text = item.title;
    if (item.isNetwork) {
        cell.detailTextLabel.text = @"Red";
    } else {
        NSMutableArray *parts = [NSMutableArray array];
        if (item.extension.length > 0) {
            [parts addObject:item.extension.uppercaseString];
        }
        if (item.duration > 0.0) {
            [parts addObject:[OVTheme formatTime:item.duration]];
        }
        cell.detailTextLabel.text = [parts componentsJoinedByString:@"  ·  "];
    }
    if (indexPath.row == self.currentIndex) {
        cell.textLabel.textColor = [OVTheme orange];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.textLabel.textColor = [OVTheme text];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.selectionHandler) {
        self.selectionHandler(indexPath.row);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
