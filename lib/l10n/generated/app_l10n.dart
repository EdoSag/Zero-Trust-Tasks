import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_l10n_en.dart';
import 'app_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @empty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get empty;

  /// No description provided for @toConfirmSuffix.
  ///
  /// In en, this message translates to:
  /// **' to confirm.'**
  String get toConfirmSuffix;

  /// No description provided for @typePrefix.
  ///
  /// In en, this message translates to:
  /// **'Type '**
  String get typePrefix;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @totalTasks.
  ///
  /// In en, this message translates to:
  /// **'Total Tasks'**
  String get totalTasks;

  /// No description provided for @allTasks.
  ///
  /// In en, this message translates to:
  /// **'All Tasks'**
  String get allTasks;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @pendingTasks.
  ///
  /// In en, this message translates to:
  /// **'Pending Tasks'**
  String get pendingTasks;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @completedTasks.
  ///
  /// In en, this message translates to:
  /// **'Completed Tasks'**
  String get completedTasks;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @overdueTasks.
  ///
  /// In en, this message translates to:
  /// **'Overdue Tasks'**
  String get overdueTasks;

  /// No description provided for @priorityBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Priority Breakdown'**
  String get priorityBreakdown;

  /// No description provided for @viewProductivityInsights.
  ///
  /// In en, this message translates to:
  /// **'View Productivity Insights'**
  String get viewProductivityInsights;

  /// No description provided for @recentTasks.
  ///
  /// In en, this message translates to:
  /// **'Recent Tasks'**
  String get recentTasks;

  /// No description provided for @noMatchingTasks.
  ///
  /// In en, this message translates to:
  /// **'No matching tasks'**
  String get noMatchingTasks;

  /// No description provided for @noTasksYet.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet'**
  String get noTasksYet;

  /// No description provided for @noTasksMatchYourCurrent.
  ///
  /// In en, this message translates to:
  /// **'No tasks match your current search or filters'**
  String get noTasksMatchYourCurrent;

  /// No description provided for @createYourFirstTaskTo.
  ///
  /// In en, this message translates to:
  /// **'Create your first task to get started'**
  String get createYourFirstTaskTo;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @createTask.
  ///
  /// In en, this message translates to:
  /// **'Create task'**
  String get createTask;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @moved1ItemFromThe.
  ///
  /// In en, this message translates to:
  /// **'Moved 1 item from the previous version'**
  String get moved1ItemFromThe;

  /// No description provided for @thatPasswordDidntOpenYour.
  ///
  /// In en, this message translates to:
  /// **'That password didn\'t open your earlier tasks. Use the password you had in the previous version of the app.'**
  String get thatPasswordDidntOpenYour;

  /// No description provided for @yourTasksFromThePrevious.
  ///
  /// In en, this message translates to:
  /// **'Your tasks from the previous version are ready to move over. Enter your password once to bring them here.'**
  String get yourTasksFromThePrevious;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get enterPassword;

  /// No description provided for @bringOverYourTasks.
  ///
  /// In en, this message translates to:
  /// **'Bring over your tasks'**
  String get bringOverYourTasks;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @tryThePasswordFromThe.
  ///
  /// In en, this message translates to:
  /// **'Try the password from the previous version'**
  String get tryThePasswordFromThe;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @linkedNotesAndContacts.
  ///
  /// In en, this message translates to:
  /// **'Linked notes and contacts'**
  String get linkedNotesAndContacts;

  /// No description provided for @noteNotFoundItMay.
  ///
  /// In en, this message translates to:
  /// **'Note not found. It may have been deleted in ZT Notes.'**
  String get noteNotFoundItMay;

  /// No description provided for @contactNotFoundItMay.
  ///
  /// In en, this message translates to:
  /// **'Contact not found. It may have been deleted in ZT Contacts.'**
  String get contactNotFoundItMay;

  /// No description provided for @linkANote.
  ///
  /// In en, this message translates to:
  /// **'Link a note'**
  String get linkANote;

  /// No description provided for @linkAContact.
  ///
  /// In en, this message translates to:
  /// **'Link a contact'**
  String get linkAContact;

  /// No description provided for @couldntLoadThisLink.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this link'**
  String get couldntLoadThisLink;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @removeLink.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get removeLink;

  /// No description provided for @thisNoteIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'This note is empty.'**
  String get thisNoteIsEmpty;

  /// No description provided for @openZtNotes.
  ///
  /// In en, this message translates to:
  /// **'Open ZT Notes'**
  String get openZtNotes;

  /// No description provided for @noAppOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'No app on this phone can do that.'**
  String get noAppOnThisPhone;

  /// No description provided for @openZtContacts.
  ///
  /// In en, this message translates to:
  /// **'Open ZT Contacts'**
  String get openZtContacts;

  /// No description provided for @linkNotes.
  ///
  /// In en, this message translates to:
  /// **'Link notes'**
  String get linkNotes;

  /// No description provided for @linkContacts.
  ///
  /// In en, this message translates to:
  /// **'Link contacts'**
  String get linkContacts;

  /// No description provided for @noNotesYetNotesYou.
  ///
  /// In en, this message translates to:
  /// **'No notes yet. Notes you write in ZT Notes with this account show up here.'**
  String get noNotesYetNotesYou;

  /// No description provided for @noContactsYetPeopleYou.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet. People you save in ZT Contacts with this account show up here.'**
  String get noContactsYetPeopleYou;

  /// No description provided for @taskAdded.
  ///
  /// In en, this message translates to:
  /// **'Task added'**
  String get taskAdded;

  /// No description provided for @newTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get newTask;

  /// No description provided for @callMumTomorrow6pm.
  ///
  /// In en, this message translates to:
  /// **'Call mum tomorrow 6pm'**
  String get callMumTomorrow6pm;

  /// No description provided for @keepAsTyped.
  ///
  /// In en, this message translates to:
  /// **'Keep as typed'**
  String get keepAsTyped;

  /// No description provided for @savedExactlyAsTyped.
  ///
  /// In en, this message translates to:
  /// **'Saved exactly as typed.'**
  String get savedExactlyAsTyped;

  /// No description provided for @readDates.
  ///
  /// In en, this message translates to:
  /// **'Read dates'**
  String get readDates;

  /// No description provided for @removeStar.
  ///
  /// In en, this message translates to:
  /// **'Remove star'**
  String get removeStar;

  /// No description provided for @star.
  ///
  /// In en, this message translates to:
  /// **'Star'**
  String get star;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @reviewBackup.
  ///
  /// In en, this message translates to:
  /// **'Review backup'**
  String get reviewBackup;

  /// No description provided for @applyingItWillMakeThe.
  ///
  /// In en, this message translates to:
  /// **'Applying it will make the following changes:'**
  String get applyingItWillMakeThe;

  /// No description provided for @yourLocalDataIsAlready.
  ///
  /// In en, this message translates to:
  /// **'Your local data is already up to date.'**
  String get yourLocalDataIsAlready;

  /// No description provided for @importFromGoogleTasks.
  ///
  /// In en, this message translates to:
  /// **'Import from Google Tasks'**
  String get importFromGoogleTasks;

  /// No description provided for @yourGoogleTakeoutZipOr.
  ///
  /// In en, this message translates to:
  /// **'Your Google Takeout .zip or Tasks.json'**
  String get yourGoogleTakeoutZipOr;

  /// No description provided for @exportBackupFile.
  ///
  /// In en, this message translates to:
  /// **'Export backup file'**
  String get exportBackupFile;

  /// No description provided for @encryptedOnlyYourAccountCan.
  ///
  /// In en, this message translates to:
  /// **'Encrypted; only your account can open it'**
  String get encryptedOnlyYourAccountCan;

  /// No description provided for @importBackupFile.
  ///
  /// In en, this message translates to:
  /// **'Import backup file'**
  String get importBackupFile;

  /// No description provided for @addsTasksFromAZtasks.
  ///
  /// In en, this message translates to:
  /// **'Adds tasks from a .ztasks file, including older versions\''**
  String get addsTasksFromAZtasks;

  /// No description provided for @templates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templates;

  /// No description provided for @reusableTaskBlueprints.
  ///
  /// In en, this message translates to:
  /// **'Reusable task blueprints'**
  String get reusableTaskBlueprints;

  /// No description provided for @trash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trash;

  /// No description provided for @deletedTasksAreKeptFor.
  ///
  /// In en, this message translates to:
  /// **'Deleted tasks are kept for 30 days'**
  String get deletedTasksAreKeptFor;

  /// No description provided for @showDetailsOnTheHome.
  ///
  /// In en, this message translates to:
  /// **'Show details on the home screen'**
  String get showDetailsOnTheHome;

  /// No description provided for @widgetShows.
  ///
  /// In en, this message translates to:
  /// **'Widget shows'**
  String get widgetShows;

  /// No description provided for @allLists.
  ///
  /// In en, this message translates to:
  /// **'All lists'**
  String get allLists;

  /// No description provided for @showTaskDetailsInNotifications.
  ///
  /// In en, this message translates to:
  /// **'Show task details in notifications'**
  String get showTaskDetailsInNotifications;

  /// No description provided for @offRemindersShowGenericText.
  ///
  /// In en, this message translates to:
  /// **'Off: reminders show generic text only (recommended)'**
  String get offRemindersShowGenericText;

  /// No description provided for @everythingIsAlreadyHere.
  ///
  /// In en, this message translates to:
  /// **'Everything is already here.'**
  String get everythingIsAlreadyHere;

  /// No description provided for @nothingIsUploadedToGoogle.
  ///
  /// In en, this message translates to:
  /// **'Nothing is uploaded to Google; your tasks are encrypted on this phone.'**
  String get nothingIsUploadedToGoogle;

  /// No description provided for @alreadyUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Already up to date'**
  String get alreadyUpToDate;

  /// No description provided for @backupFileSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup file saved'**
  String get backupFileSaved;

  /// No description provided for @backupFromAnEarlierVersion.
  ///
  /// In en, this message translates to:
  /// **'Backup from an earlier version'**
  String get backupFromAnEarlierVersion;

  /// No description provided for @passwordUsedWhenTheBackup.
  ///
  /// In en, this message translates to:
  /// **'Password used when the backup was made'**
  String get passwordUsedWhenTheBackup;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @noTasksDueOnThis.
  ///
  /// In en, this message translates to:
  /// **'No tasks due on this day'**
  String get noTasksDueOnThis;

  /// No description provided for @taskMarkedIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Task marked incomplete'**
  String get taskMarkedIncomplete;

  /// No description provided for @taskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Task completed'**
  String get taskCompleted;

  /// No description provided for @filterSort.
  ///
  /// In en, this message translates to:
  /// **'Filter & sort'**
  String get filterSort;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @starred.
  ///
  /// In en, this message translates to:
  /// **'Starred'**
  String get starred;

  /// No description provided for @newList.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get newList;

  /// No description provided for @moveToList.
  ///
  /// In en, this message translates to:
  /// **'Move to list'**
  String get moveToList;

  /// No description provided for @renameOrChangeColour.
  ///
  /// In en, this message translates to:
  /// **'Rename or change colour'**
  String get renameOrChangeColour;

  /// No description provided for @deleteList.
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get deleteList;

  /// No description provided for @theDefaultListCantBe.
  ///
  /// In en, this message translates to:
  /// **'The default list can\'t be deleted'**
  String get theDefaultListCantBe;

  /// No description provided for @theListIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The list is empty.'**
  String get theListIsEmpty;

  /// No description provided for @makeASubtaskOf.
  ///
  /// In en, this message translates to:
  /// **'Make a subtask of…'**
  String get makeASubtaskOf;

  /// No description provided for @noOtherOpenTasks.
  ///
  /// In en, this message translates to:
  /// **'No other open tasks'**
  String get noOtherOpenTasks;

  /// No description provided for @editList.
  ///
  /// In en, this message translates to:
  /// **'Edit list'**
  String get editList;

  /// No description provided for @listName.
  ///
  /// In en, this message translates to:
  /// **'List name'**
  String get listName;

  /// No description provided for @defaultColour.
  ///
  /// In en, this message translates to:
  /// **'Default colour'**
  String get defaultColour;

  /// No description provided for @colour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get colour;

  /// No description provided for @searchTasksDescriptionsCategories.
  ///
  /// In en, this message translates to:
  /// **'Search tasks, descriptions, categories...'**
  String get searchTasksDescriptionsCategories;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @editTask.
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get editTask;

  /// No description provided for @newTask2.
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get newTask2;

  /// No description provided for @useATemplate.
  ///
  /// In en, this message translates to:
  /// **'Use a template'**
  String get useATemplate;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title *'**
  String get title;

  /// No description provided for @titleIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get titleIsRequired;

  /// No description provided for @chooseAList.
  ///
  /// In en, this message translates to:
  /// **'Choose a list'**
  String get chooseAList;

  /// No description provided for @saveInList.
  ///
  /// In en, this message translates to:
  /// **'Save in list'**
  String get saveInList;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @noStartDate.
  ///
  /// In en, this message translates to:
  /// **'No start date'**
  String get noStartDate;

  /// No description provided for @clearStartDate.
  ///
  /// In en, this message translates to:
  /// **'Clear start date'**
  String get clearStartDate;

  /// No description provided for @noDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get noDueDate;

  /// No description provided for @clearDueDate.
  ///
  /// In en, this message translates to:
  /// **'Clear due date'**
  String get clearDueDate;

  /// No description provided for @noReminder.
  ///
  /// In en, this message translates to:
  /// **'No reminder'**
  String get noReminder;

  /// No description provided for @clearReminder.
  ///
  /// In en, this message translates to:
  /// **'Clear reminder'**
  String get clearReminder;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @noRepeat.
  ///
  /// In en, this message translates to:
  /// **'No repeat'**
  String get noRepeat;

  /// No description provided for @every.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get every;

  /// No description provided for @noEndDate.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get noEndDate;

  /// No description provided for @clearEndDate.
  ///
  /// In en, this message translates to:
  /// **'Clear end date'**
  String get clearEndDate;

  /// No description provided for @addTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get addTag;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @addLinkUrl.
  ///
  /// In en, this message translates to:
  /// **'Add link (URL)'**
  String get addLinkUrl;

  /// No description provided for @subTasks.
  ///
  /// In en, this message translates to:
  /// **'Sub-tasks'**
  String get subTasks;

  /// No description provided for @noSubTasks.
  ///
  /// In en, this message translates to:
  /// **'No sub-tasks'**
  String get noSubTasks;

  /// No description provided for @subTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Sub-task title'**
  String get subTaskTitle;

  /// No description provided for @deleteSubTask.
  ///
  /// In en, this message translates to:
  /// **'Delete sub-task'**
  String get deleteSubTask;

  /// No description provided for @updateTask.
  ///
  /// In en, this message translates to:
  /// **'Update Task'**
  String get updateTask;

  /// No description provided for @saveTask.
  ///
  /// In en, this message translates to:
  /// **'Save Task'**
  String get saveTask;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// No description provided for @activeTasksByPriority.
  ///
  /// In en, this message translates to:
  /// **'Active Tasks by Priority'**
  String get activeTasksByPriority;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @doneStat.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneStat;

  /// No description provided for @avgDay.
  ///
  /// In en, this message translates to:
  /// **'Avg/day'**
  String get avgDay;

  /// No description provided for @noActiveTasks.
  ///
  /// In en, this message translates to:
  /// **'No active tasks'**
  String get noActiveTasks;

  /// No description provided for @encryptedHowYourDataIs.
  ///
  /// In en, this message translates to:
  /// **'Encrypted: how your data is protected'**
  String get encryptedHowYourDataIs;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @taskDetails.
  ///
  /// In en, this message translates to:
  /// **'Task Details'**
  String get taskDetails;

  /// No description provided for @editTask2.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get editTask2;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @saveAsTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save as template'**
  String get saveAsTemplate;

  /// No description provided for @unarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchive;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @priority2.
  ///
  /// In en, this message translates to:
  /// **'Priority: '**
  String get priority2;

  /// No description provided for @category2.
  ///
  /// In en, this message translates to:
  /// **'Category: '**
  String get category2;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date: '**
  String get startDate;

  /// No description provided for @due.
  ///
  /// In en, this message translates to:
  /// **'Due: '**
  String get due;

  /// No description provided for @repeats.
  ///
  /// In en, this message translates to:
  /// **'Repeats: '**
  String get repeats;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder: '**
  String get reminder;

  /// No description provided for @links.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get links;

  /// No description provided for @taskDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Task duplicated'**
  String get taskDuplicated;

  /// No description provided for @templateName.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get templateName;

  /// No description provided for @templateSaved.
  ///
  /// In en, this message translates to:
  /// **'Template saved'**
  String get templateSaved;

  /// No description provided for @taskUnarchived.
  ///
  /// In en, this message translates to:
  /// **'Task unarchived'**
  String get taskUnarchived;

  /// No description provided for @taskArchived.
  ///
  /// In en, this message translates to:
  /// **'Task archived'**
  String get taskArchived;

  /// No description provided for @taskDeleted.
  ///
  /// In en, this message translates to:
  /// **'Task deleted'**
  String get taskDeleted;

  /// No description provided for @saveCurrentFilter.
  ///
  /// In en, this message translates to:
  /// **'Save current filter'**
  String get saveCurrentFilter;

  /// No description provided for @filterName.
  ///
  /// In en, this message translates to:
  /// **'Filter name'**
  String get filterName;

  /// No description provided for @setCategory.
  ///
  /// In en, this message translates to:
  /// **'Set category'**
  String get setCategory;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @setPriority.
  ///
  /// In en, this message translates to:
  /// **'Set priority'**
  String get setPriority;

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'Due Today'**
  String get dueToday;

  /// No description provided for @upcomingTasks.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Tasks'**
  String get upcomingTasks;

  /// No description provided for @cancelSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get cancelSelection;

  /// No description provided for @selectTasks.
  ///
  /// In en, this message translates to:
  /// **'Select tasks'**
  String get selectTasks;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @filterAndSort.
  ///
  /// In en, this message translates to:
  /// **'Filter and sort'**
  String get filterAndSort;

  /// No description provided for @switchToFlatList.
  ///
  /// In en, this message translates to:
  /// **'Switch to flat list'**
  String get switchToFlatList;

  /// No description provided for @switchToSectionedList.
  ///
  /// In en, this message translates to:
  /// **'Switch to sectioned list'**
  String get switchToSectionedList;

  /// No description provided for @switchToList.
  ///
  /// In en, this message translates to:
  /// **'Switch to list'**
  String get switchToList;

  /// No description provided for @switchToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Switch to calendar'**
  String get switchToCalendar;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// No description provided for @deleteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Delete template?'**
  String get deleteTemplate;

  /// No description provided for @deleteTemplate2.
  ///
  /// In en, this message translates to:
  /// **'Delete template'**
  String get deleteTemplate2;

  /// No description provided for @useTemplate.
  ///
  /// In en, this message translates to:
  /// **'Use template'**
  String get useTemplate;

  /// No description provided for @noTemplatesYet.
  ///
  /// In en, this message translates to:
  /// **'No templates yet'**
  String get noTemplatesYet;

  /// No description provided for @openATaskAndUse.
  ///
  /// In en, this message translates to:
  /// **'Open a task and use \"Save as template\" from the menu to create one.'**
  String get openATaskAndUse;

  /// No description provided for @trashIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Trash is empty'**
  String get trashIsEmpty;

  /// No description provided for @deletedTasksAreKeptFor2.
  ///
  /// In en, this message translates to:
  /// **'Deleted tasks are kept for 30 days.'**
  String get deletedTasksAreKeptFor2;

  /// No description provided for @tasksArePermanentlyDeletedAfter.
  ///
  /// In en, this message translates to:
  /// **'Tasks are permanently deleted after 30 days.'**
  String get tasksArePermanentlyDeletedAfter;

  /// No description provided for @deleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get deleteForever;

  /// No description provided for @taskRestored.
  ///
  /// In en, this message translates to:
  /// **'Task restored'**
  String get taskRestored;

  /// No description provided for @deleteForever2.
  ///
  /// In en, this message translates to:
  /// **'Delete forever?'**
  String get deleteForever2;

  /// No description provided for @emptyTrash.
  ///
  /// In en, this message translates to:
  /// **'Empty trash?'**
  String get emptyTrash;

  /// No description provided for @movedItems.
  ///
  /// In en, this message translates to:
  /// **'Moved {count} items from the previous version'**
  String movedItems(int count);

  /// No description provided for @legacyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t bring over your tasks from the previous version yet. {error}'**
  String legacyFailed(String error);

  /// No description provided for @legacyExplain.
  ///
  /// In en, this message translates to:
  /// **'Your earlier tasks were encrypted with your password. It is used on this phone only, to open them once.'**
  String get legacyExplain;

  /// No description provided for @callNumber.
  ///
  /// In en, this message translates to:
  /// **'Call {number}'**
  String callNumber(String number);

  /// No description provided for @textNumber.
  ///
  /// In en, this message translates to:
  /// **'Text {number}'**
  String textNumber(String number);

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email {address}'**
  String emailAddress(String address);

  /// No description provided for @searchNotes.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get searchNotes;

  /// No description provided for @searchContacts.
  ///
  /// In en, this message translates to:
  /// **'Search contacts'**
  String get searchContacts;

  /// No description provided for @cantLoadNotes.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your notes. {error}'**
  String cantLoadNotes(String error);

  /// No description provided for @cantLoadContacts.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your contacts. {error}'**
  String cantLoadContacts(String error);

  /// No description provided for @openApp.
  ///
  /// In en, this message translates to:
  /// **'Open {app}'**
  String openApp(String app);

  /// No description provided for @nothingMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches \"{query}\".'**
  String nothingMatches(String query);

  /// No description provided for @priorityTasks.
  ///
  /// In en, this message translates to:
  /// **'{priority} Priority Tasks'**
  String priorityTasks(String priority);

  /// No description provided for @taskAddedDue.
  ///
  /// In en, this message translates to:
  /// **'Task added, due {when}'**
  String taskAddedDue(String when);

  /// No description provided for @cantAddTask.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the task: {error}'**
  String cantAddTask(String error);

  /// No description provided for @quickAddHelp.
  ///
  /// In en, this message translates to:
  /// **'Dates and times are read as you type, in English or Hebrew. Also: every week, !high, #tag'**
  String get quickAddHelp;

  /// No description provided for @titleIs.
  ///
  /// In en, this message translates to:
  /// **'Title: {title}'**
  String titleIs(String title);

  /// No description provided for @listIs.
  ///
  /// In en, this message translates to:
  /// **'List: {list}'**
  String listIs(String list);

  /// No description provided for @everyNDays.
  ///
  /// In en, this message translates to:
  /// **'Every {n} days'**
  String everyNDays(int n);

  /// No description provided for @everyNWeeks.
  ///
  /// In en, this message translates to:
  /// **'Every {n} weeks'**
  String everyNWeeks(int n);

  /// No description provided for @everyNMonths.
  ///
  /// In en, this message translates to:
  /// **'Every {n} months'**
  String everyNMonths(int n);

  /// No description provided for @everyNYears.
  ///
  /// In en, this message translates to:
  /// **'Every {n} years'**
  String everyNYears(int n);

  /// No description provided for @backupContains.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This backup contains 1 task. Applying it will make the following changes:} other{This backup contains {count} tasks. Applying it will make the following changes:}}'**
  String backupContains(int count);

  /// No description provided for @tasksAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task added} other{{count} tasks added}}'**
  String tasksAdded(int count);

  /// No description provided for @tasksUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task updated} other{{count} tasks updated}}'**
  String tasksUpdated(int count);

  /// No description provided for @tasksRemoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task removed} other{{count} tasks removed}}'**
  String tasksRemoved(int count);

  /// No description provided for @widgetDetailsBody.
  ///
  /// In en, this message translates to:
  /// **'Off: the widget shows counts only. On: the titles of your next tasks are stored unencrypted on this phone for the home screen, so anyone holding the unlocked phone can see them'**
  String get widgetDetailsBody;

  /// No description provided for @savedFile.
  ///
  /// In en, this message translates to:
  /// **'Saved {file}'**
  String savedFile(String file);

  /// No description provided for @googleTasksFound.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks found.'**
  String googleTasksFound(int count);

  /// No description provided for @googleTasksFoundInLists.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks found in {lists, plural, =1{1 new list} other{{lists} new lists}}.'**
  String googleTasksFoundInLists(int count, int lists);

  /// No description provided for @willBeAdded.
  ///
  /// In en, this message translates to:
  /// **'{count} will be added.'**
  String willBeAdded(int count);

  /// No description provided for @willBeUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count} already here will be updated.'**
  String willBeUpdated(int count);

  /// No description provided for @importedFromGoogle.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} tasks from Google Tasks'**
  String importedFromGoogle(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @importedTasks.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} tasks'**
  String importedTasks(int count);

  /// No description provided for @markNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark \"{title}\" as not completed'**
  String markNotCompleted(String title);

  /// No description provided for @markCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark \"{title}\" as completed'**
  String markCompleted(String title);

  /// No description provided for @removeStarFrom.
  ///
  /// In en, this message translates to:
  /// **'Remove star from \"{title}\"'**
  String removeStarFrom(String title);

  /// No description provided for @starTask.
  ///
  /// In en, this message translates to:
  /// **'Star \"{title}\"'**
  String starTask(String title);

  /// No description provided for @starredCount.
  ///
  /// In en, this message translates to:
  /// **'Starred {count}'**
  String starredCount(int count);

  /// No description provided for @deleteListQ.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteListQ(String name);

  /// No description provided for @listTasksToTrash.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Its 1 task goes to Trash, where it stays for 30 days.} other{Its {count} tasks go to Trash, where they stay for 30 days.}}'**
  String listTasksToTrash(int count);

  /// No description provided for @cantOpenTasks.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open your tasks on this device. {error}'**
  String cantOpenTasks(String error);

  /// No description provided for @savedChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Saved 1 change from a reminder or widget} other{Saved {count} changes from reminders or the widget}}'**
  String savedChanges(int count);

  /// No description provided for @startOn.
  ///
  /// In en, this message translates to:
  /// **'Start: {date}'**
  String startOn(String date);

  /// No description provided for @dueOn.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String dueOn(String date);

  /// No description provided for @remindOn.
  ///
  /// In en, this message translates to:
  /// **'Remind: {date}'**
  String remindOn(String date);

  /// No description provided for @endsOn.
  ///
  /// In en, this message translates to:
  /// **'Ends: {date}'**
  String endsOn(String date);

  /// No description provided for @everyN.
  ///
  /// In en, this message translates to:
  /// **' every {n}'**
  String everyN(int n);

  /// No description provided for @subtasksProgress.
  ///
  /// In en, this message translates to:
  /// **'Sub-tasks ({done}/{total})'**
  String subtasksProgress(int done, int total);

  /// No description provided for @promoteSubtask.
  ///
  /// In en, this message translates to:
  /// **'Make \"{title}\" a task of its own'**
  String promoteSubtask(String title);

  /// No description provided for @createdOn.
  ///
  /// In en, this message translates to:
  /// **'Created: {date}'**
  String createdOn(String date);

  /// No description provided for @updatedOn.
  ///
  /// In en, this message translates to:
  /// **'Last updated: {date}'**
  String updatedOn(String date);

  /// No description provided for @movedTo.
  ///
  /// In en, this message translates to:
  /// **'Moved to {list}'**
  String movedTo(String list);

  /// No description provided for @nowSubtaskOf.
  ///
  /// In en, this message translates to:
  /// **'Now a subtask of \"{title}\"'**
  String nowSubtaskOf(String title);

  /// No description provided for @nowOwnTask.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" is now a task of its own'**
  String nowOwnTask(String title);

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update task: {error}'**
  String updateFailed(String error);

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete task: {error}'**
  String deleteFailed(String error);

  /// No description provided for @completionsLastDays.
  ///
  /// In en, this message translates to:
  /// **'Completions – Last {days} Days'**
  String completionsLastDays(int days);

  /// No description provided for @nCompleted.
  ///
  /// In en, this message translates to:
  /// **'{count} completed'**
  String nCompleted(int count);

  /// No description provided for @nTasks.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks'**
  String nTasks(int count);

  /// No description provided for @dayDone.
  ///
  /// In en, this message translates to:
  /// **'{day}\n{count} done'**
  String dayDone(String day, int count);

  /// No description provided for @movedTasksTo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Moved 1 task to {list}} other{Moved {count} tasks to {list}}}'**
  String movedTasksTo(int count, String list);

  /// No description provided for @tasksTrashed.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks moved to trash'**
  String tasksTrashed(int count);

  /// No description provided for @nSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String nSelected(int count);

  /// No description provided for @willBeRemoved.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be removed.'**
  String willBeRemoved(String title);

  /// No description provided for @nSubtasks.
  ///
  /// In en, this message translates to:
  /// **'{count} sub-tasks'**
  String nSubtasks(int count);

  /// No description provided for @deletedDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Deleted {date} · 1 day left} other{Deleted {date} · {count} days left}}'**
  String deletedDaysLeft(int count, String date);

  /// No description provided for @permDeleteOne.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be permanently deleted and cannot be recovered.'**
  String permDeleteOne(String title);

  /// No description provided for @permDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The 1 task will be permanently deleted.} other{All {count} tasks will be permanently deleted.}}'**
  String permDeleteAll(int count);

  /// No description provided for @deletePhrase.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deletePhrase;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @dueDateEarliestFirst.
  ///
  /// In en, this message translates to:
  /// **'Due date (earliest first)'**
  String get dueDateEarliestFirst;

  /// No description provided for @dueDateLatestFirst.
  ///
  /// In en, this message translates to:
  /// **'Due date (latest first)'**
  String get dueDateLatestFirst;

  /// No description provided for @dateCreated.
  ///
  /// In en, this message translates to:
  /// **'Date created'**
  String get dateCreated;

  /// No description provided for @alphabetical.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get alphabetical;

  /// No description provided for @myOrderDragToReorder.
  ///
  /// In en, this message translates to:
  /// **'My order (drag to reorder)'**
  String get myOrderDragToReorder;

  /// No description provided for @dueToday2.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dueToday2;

  /// No description provided for @critical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get critical;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @dueSoon.
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get dueSoon;

  /// No description provided for @nothingToDo.
  ///
  /// In en, this message translates to:
  /// **'Nothing to do'**
  String get nothingToDo;

  /// No description provided for @allTasks2.
  ///
  /// In en, this message translates to:
  /// **'All tasks'**
  String get allTasks2;

  /// No description provided for @yourTasks.
  ///
  /// In en, this message translates to:
  /// **'Your tasks'**
  String get yourTasks;

  /// No description provided for @signedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get signedOut;

  /// No description provided for @taskReminders.
  ///
  /// In en, this message translates to:
  /// **'Task Reminders'**
  String get taskReminders;

  /// No description provided for @remindersForYourTasks.
  ///
  /// In en, this message translates to:
  /// **'Reminders for your tasks'**
  String get remindersForYourTasks;

  /// No description provided for @snooze1Hour.
  ///
  /// In en, this message translates to:
  /// **'Snooze 1 hour'**
  String get snooze1Hour;

  /// No description provided for @taskReminder.
  ///
  /// In en, this message translates to:
  /// **'Task reminder'**
  String get taskReminder;

  /// No description provided for @youHaveATaskReminder.
  ///
  /// In en, this message translates to:
  /// **'You have a task reminder.'**
  String get youHaveATaskReminder;

  /// No description provided for @thisIsntAZeroTrust.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a Zero-Trust Tasks backup file.'**
  String get thisIsntAZeroTrust;

  /// No description provided for @thisBackupBelongsToAnother.
  ///
  /// In en, this message translates to:
  /// **'This backup belongs to another account.'**
  String get thisBackupBelongsToAnother;

  /// No description provided for @thisBackupFileIsDamaged.
  ///
  /// In en, this message translates to:
  /// **'This backup file is damaged.'**
  String get thisBackupFileIsDamaged;

  /// No description provided for @thatPasswordDoesntOpenThis.
  ///
  /// In en, this message translates to:
  /// **'That password doesn\'t open this backup.'**
  String get thatPasswordDoesntOpenThis;

  /// No description provided for @thisBackupIsFromA.
  ///
  /// In en, this message translates to:
  /// **'This backup is from a newer version of the app.'**
  String get thisBackupIsFromA;

  /// No description provided for @untitledNote.
  ///
  /// In en, this message translates to:
  /// **'Untitled note'**
  String get untitledNote;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @nOpen.
  ///
  /// In en, this message translates to:
  /// **'{count} open'**
  String nOpen(int count);

  /// No description provided for @nDueToday.
  ///
  /// In en, this message translates to:
  /// **'{count} due today'**
  String nDueToday(int count);

  /// No description provided for @nOverdue.
  ///
  /// In en, this message translates to:
  /// **'{count} overdue'**
  String nOverdue(int count);

  /// No description provided for @overdueLabel.
  ///
  /// In en, this message translates to:
  /// **'Overdue · {date}'**
  String overdueLabel(String date);

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String daysAgo(int count);

  /// No description provided for @monthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month ago} other{{count} months ago}}'**
  String monthsAgo(int count);

  /// No description provided for @yearsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year ago} other{{count} years ago}}'**
  String yearsAgo(int count);

  /// No description provided for @cantReadTasks.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read your tasks: {error}'**
  String cantReadTasks(String error);

  /// No description provided for @copyOf.
  ///
  /// In en, this message translates to:
  /// **'{title} (Copy)'**
  String copyOf(String title);

  /// No description provided for @widgetAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add a task'**
  String get widgetAddTask;

  /// No description provided for @widgetCompleteTask.
  ///
  /// In en, this message translates to:
  /// **'Complete task'**
  String get widgetCompleteTask;

  /// No description provided for @widgetOpenToSee.
  ///
  /// In en, this message translates to:
  /// **'Open ZT Tasks to see your tasks'**
  String get widgetOpenToSee;

  /// No description provided for @widgetOpenAppSummary.
  ///
  /// In en, this message translates to:
  /// **'Open the app to see your tasks'**
  String get widgetOpenAppSummary;

  /// No description provided for @widgetDoneSaved.
  ///
  /// In en, this message translates to:
  /// **'Done. Saved when you next open the app'**
  String get widgetDoneSaved;

  /// No description provided for @shareListQ.
  ///
  /// In en, this message translates to:
  /// **'Share \"{name}\"'**
  String shareListQ(String name);

  /// No description provided for @shareList.
  ///
  /// In en, this message translates to:
  /// **'Share list'**
  String get shareList;

  /// No description provided for @newSharedList.
  ///
  /// In en, this message translates to:
  /// **'New shared list'**
  String get newSharedList;

  /// No description provided for @joinSharedList.
  ///
  /// In en, this message translates to:
  /// **'Join a shared list'**
  String get joinSharedList;

  /// No description provided for @joinListChip.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinListChip;

  /// No description provided for @sharingNeedsInternet.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Sharing needs an internet connection.'**
  String get sharingNeedsInternet;

  /// No description provided for @waitingToJoin.
  ///
  /// In en, this message translates to:
  /// **'Waiting to join'**
  String get waitingToJoin;

  /// No description provided for @sharedListE2e.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted. Everyone here can add, edit and tick off tasks; owners can also rename the list and invite or remove people.'**
  String get sharedListE2e;

  /// No description provided for @youName.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String youName(String name);

  /// No description provided for @invitePeople.
  ///
  /// In en, this message translates to:
  /// **'Invite people'**
  String get invitePeople;

  /// No description provided for @joinRequestFor.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to join \"{list}\"'**
  String joinRequestFor(String name, String list);

  /// No description provided for @joinRequestHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to compare codes and let them in'**
  String get joinRequestHint;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @sharedWith.
  ///
  /// In en, this message translates to:
  /// **'Shared with {names}'**
  String sharedWith(String names);

  /// No description provided for @sharedListOptions.
  ///
  /// In en, this message translates to:
  /// **'People and sharing'**
  String get sharedListOptions;

  /// No description provided for @onlyOwnersRename.
  ///
  /// In en, this message translates to:
  /// **'Only owners can rename this list'**
  String get onlyOwnersRename;

  /// No description provided for @locationReminder.
  ///
  /// In en, this message translates to:
  /// **'Location reminder'**
  String get locationReminder;

  /// No description provided for @noLocationReminder.
  ///
  /// In en, this message translates to:
  /// **'No location reminder'**
  String get noLocationReminder;

  /// No description provided for @remindArriveAt.
  ///
  /// In en, this message translates to:
  /// **'When I arrive at {place}'**
  String remindArriveAt(String place);

  /// No description provided for @remindLeave.
  ///
  /// In en, this message translates to:
  /// **'When I leave {place}'**
  String remindLeave(String place);

  /// No description provided for @clearLocationReminder.
  ///
  /// In en, this message translates to:
  /// **'Remove location reminder'**
  String get clearLocationReminder;

  /// No description provided for @arrivedAt.
  ///
  /// In en, this message translates to:
  /// **'You arrived at {place}'**
  String arrivedAt(String place);

  /// No description provided for @leftPlace.
  ///
  /// In en, this message translates to:
  /// **'You left {place}'**
  String leftPlace(String place);

  /// No description provided for @placeRemindersChannel.
  ///
  /// In en, this message translates to:
  /// **'Location reminders'**
  String get placeRemindersChannel;

  /// No description provided for @placeRemindersChannelHint.
  ///
  /// In en, this message translates to:
  /// **'Task reminders when you arrive at or leave a place'**
  String get placeRemindersChannelHint;

  /// No description provided for @locationStaysOnPhone.
  ///
  /// In en, this message translates to:
  /// **'Your phone watches the place itself. Your location is never sent anywhere, and the place is kept encrypted in your vault, not in shared lists.'**
  String get locationStaysOnPhone;

  /// No description provided for @aPlace.
  ///
  /// In en, this message translates to:
  /// **'a place'**
  String get aPlace;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'he':
      return AppL10nHe();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
