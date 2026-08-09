---
title: mdls and Spotlight Metadata Attributes
tags:
  - manpage
  - macOS
  - cli
  - Spotlight
---

`mdls` prints Spotlight metadata attributes for files and bundles. This manual covers its command-line interface, shows how to discover valid attribute names, and includes the complete attribute registry reported by this Mac when the document was generated.

## Quick start

Print every indexed attribute and value for a file:

```sh
mdls "/path/to/file"
```

Print one attribute:

```sh
mdls -name kMDItemVersion "/Applications/My App.app"
```

Print several attributes:

```sh
mdls \
  -name kMDItemDisplayName \
  -name kMDItemVersion \
  -name kMDItemCFBundleIdentifier \
  "/Applications/My App.app"
```

For an application bundle, the most useful fields are commonly:

| Attribute | Meaning |
|---|---|
| `kMDItemVersion` | User-facing application version indexed by Spotlight |
| `kMDItemCFBundleIdentifier` | Bundle identifier, such as `com.example.app` |
| `kMDItemDisplayName` | Localized display name |
| `kMDItemExecutableArchitectures` | Indexed executable architectures |
| `kMDItemContentType` | Uniform Type Identifier (UTI) |
| `kMDItemContentTypeTree` | UTI and its conformance hierarchy |
| `kMDItemAppStoreCategory` | App Store category, when present |
| `kMDItemApplicationCategories` | Application category identifiers, when present |

`mdls` reads the Spotlight index, not `Info.plist` directly. For authoritative bundle version keys, bypass Spotlight:

```sh
plist="/Applications/My App.app/Contents/Info.plist"
plutil -extract CFBundleShortVersionString raw -- "$plist"  # release version
plutil -extract CFBundleVersion raw -- "$plist"             # build number
```

## Syntax and options

```text
mdls [-name attributeName] [-raw [-nullMarker markerString]] file ...
```

| Option | Effect |
|---|---|
| `-name attributeName` | Print only that attribute. Repeat the option to request multiple attributes. |
| `-raw` | Print values without attribute labels. Multiple fields are separated by an ASCII NUL byte. |
| `-nullMarker markerString` | In raw mode, replace a null value with this string. The default is `(null)`. |

Always quote paths containing spaces. A missing or unindexed attribute prints `(null)` in normal output.

### Script-safe output

For one scalar field, command substitution is convenient:

```sh
version=$(mdls -raw -nullMarker '' -name kMDItemVersion "/Applications/My App.app")
```

For multiple raw fields, consume NUL delimiters rather than treating the output as lines:

```sh
mdls -raw \
  -name kMDItemCFBundleIdentifier \
  -name kMDItemVersion \
  "/Applications/My App.app" |
while IFS= read -r -d '' value; do
  printf '%s\n' "$value"
done
```

The `mdls(1)` manual says raw values follow request order. On macOS 26.4.1, repeated `-name` output was observed in attribute-name order, so scripts should not map unlabeled multi-value output by position without testing the target OS. Separate one-attribute calls are safer when identity matters.

## Finding valid `-name` values

There is no machine-independent, permanently complete list. Spotlight's schema is extensible: macOS, Apple applications, and third-party metadata importers can register attributes. Use the installed schema as the authority.

List every registered attribute with its localized label, description, and search aliases:

```sh
mdimport -A
```

Print only attribute names:

```sh
mdimport -A | awk -F "'" '{print $2}'
```

Search the registry case-insensitively:

```sh
mdimport -A | grep -i 'version\|bundle'
```

Other useful schema and importer diagnostics:

```sh
mdimport -X   # print the active metadata schema
mdimport -L   # list installed metadata importers
```

To discover which attributes actually exist on a particular item, omit `-name`:

```sh
mdls "/path/to/item"
```

To find files by metadata, use `mdfind`, for example:

```sh
mdfind 'kMDItemCFBundleIdentifier == "com.apple.calculator"'
mdfind 'kMDItemVersion == "12.0"'
```

## Why a value may be null or stale

- The importer for that file type does not produce the attribute.
- The item has not been indexed yet, or the index is stale.
- Spotlight indexing is disabled for the volume or location.
- The attribute is registered globally but applies only to another content type.
- A bundle's `Info.plist` key does not necessarily map to a same-named Spotlight attribute.

Inspect indexing state with `mdutil -s /`. For direct application-bundle facts, prefer `plutil` as shown above.

## Registered attribute catalog

Generated on 2026-08-08 from `mdimport -A` on macOS 26.4.1 (build 25E253). It contains **317 attributes**. “Label,” “description,” and “aliases” are the localized values returned by the system; an em dash means the registry returned `(null)`. Private names beginning with `_` and vendor-prefixed names are included because they are accepted registered attributes on this Mac, but they are not stable public API.

| Attribute (`-name` value) | Label | Description | Search aliases |
|---|---|---|---|
| `MessageGUIDs` | — | — | — |
| `_kMDItemContactIdentifier` | — | — | — |
| `_kMDItemDomainIdentifier` | — | — | — |
| `_kMDItemIsCommunicationNotification` | — | — | — |
| `_kMDItemIsFromMe` | — | — | — |
| `_kMDItemIsGroupThread` | — | — | — |
| `_kMDItemIsNew` | — | — | — |
| `_kMDItemIsShared` | Is shared | Whether this file is shared via iCloud | — |
| `_kMDItemIsTemplateApp` | — | — | — |
| `_kMDItemIsTwoFactorCode` | — | — | — |
| `_kMDItemIsUrgent` | — | — | — |
| `_kMDItemIsWindowTabEntity` | — | — | — |
| `_kMDItemMailCategories` | — | — | — |
| `_kMDItemMailCategoryType` | — | — | — |
| `_kMDItemMailVIP` | — | — | — |
| `_kMDItemMediaEmbeddingVersion` | — | — | — |
| `_kMDItemMediaTimeRangeEmbeddings` | — | — | — |
| `_kMDItemMessageEffectType` | — | — | — |
| `_kMDItemMessageFromKnownSender` | — | — | — |
| `_kMDItemMessageMentionedAddresses` | — | — | — |
| `_kMDItemMessagePinned` | — | — | — |
| `_kMDItemMessageRead` | — | — | — |
| `_kMDItemMessageService` | — | — | — |
| `_kMDItemMessageTapbackStringValue` | — | — | — |
| `_kMDItemMessageTapbackType` | — | — | — |
| `_kMDItemMessageType` | — | — | — |
| `_kMDItemNotificationCritical` | — | — | — |
| `_kMDItemNotificationTimeSensitive` | — | — | — |
| `_kMDItemOwnerName` | Shared file owner | The owner of this shared file | — |
| `_kMDItemPersonIdentifier` | — | — | — |
| `_kMDItemPersonIdentifiers` | — | — | — |
| `_kMDItemPhotoEmbedding` | — | — | — |
| `_kMDItemPhotosIdentificationDocumentsVersion` | — | — | — |
| `_kMDItemPrimaryTextEmbedding` | — | — | — |
| `_kMDItemRequiresMediaAnalysis` | — | — | — |
| `_kMDItemRequiresMediaComplete` | — | — | — |
| `_kMDItemSecondaryTextEmbedding` | — | — | — |
| `_kMDItemSharedItemCurrentUserRole` | User role | The role of the current user pertaining to this file (owner or participant) | — |
| `_kMDItemSharedProjectID` | Shared project ID | The project ID of this shared item | — |
| `_kMDItemSmartRepliesResponse` | — | — | — |
| `_kMDItemSmartRepliesStatus` | — | — | — |
| `_kMDItemSummarizationContentSynopsis` | — | — | — |
| `_kMDItemSummarizationContentTopLine` | — | — | — |
| `_kMDItemSummarizationContentTopic` | — | — | — |
| `_kMDItemSummarizationStatus` | — | — | — |
| `_kMDItemSummarizedIdentifiers` | — | — | — |
| `_kMDItemTapbackAssociatedMessageID` | — | — | — |
| `_kMDItemTextChunkTokenLength` | — | — | — |
| `_kMDItemThreadIdentifier` | — | — | — |
| `_kMDItemTimeSensitiveStatus` | — | — | — |
| `_kMDItemURLCanBeHiddenBySystem` | — | — | — |
| `_kMDItemUrgencyStatus` | — | — | — |
| `_kMDItemUserTags` | — | — | — |
| `com_apple_ats_name_family` | Family name | Font Family name | — |
| `com_apple_ats_name_fond` | FOND name | FOND name | — |
| `com_apple_ats_name_full` | Full name | Font Full name | — |
| `com_apple_ats_name_postscript` | PostScript name | PostScript name | — |
| `com_apple_ats_name_style` | Style name | Font Style name | — |
| `com_apple_ats_names` | — | — | — |
| `com_apple_garageband_metadata_numberOfRITracks` | Real instrument tracks | Number of real instrument tracks in GarageBand song | — |
| `com_apple_garageband_metadata_numberOfSITracks` | Software instrument tracks | Number of software instrument tracks in GarageBand song | — |
| `com_apple_garageband_metadata_parentalAdvisory` | Parental advisory | GarageBand parental advisory | — |
| `com_apple_garageband_metadata_projectType` | Type | GarageBand project type | — |
| `com_apple_garageband_metadata_songVersionNumber` | Created with version | The GarageBand version used to create this song | — |
| `com_apple_iCal_Bookmark_SharedUID` | — | — | — |
| `com_apple_mail_attachmentKinds` | — | — | — |
| `com_apple_mail_attachmentNames` | Attachment Names | A list of the names of attachments associated with a message | — |
| `com_apple_mail_attachmentSpecificTypes` | — | — | — |
| `com_apple_mail_attachmentTypes` | Attachment Types | A list of the types for attachments associated with a message | — |
| `com_apple_mail_dateLastViewed` | Date Last Viewed | The date a message was last viewed | — |
| `com_apple_mail_dateReceived` | Date Received | The date a message was received | — |
| `com_apple_mail_flagColor` | Flag Color | The color of the flag associated with a message | — |
| `com_apple_mail_flagged` | Flagged | Whether or not a message is flagged | — |
| `com_apple_mail_messageID` | Message ID | The message ID from the message header | — |
| `com_apple_mail_priority` | Priority | The numbered priority of a message | — |
| `com_apple_mail_read` | Read Status | Whether or not a message has been read | — |
| `com_apple_mail_repliedTo` | Replied To | Whether or not a message has been replied to | — |
| `com_apple_xcode_dsym_paths` | dSYM paths | dSYM bundle relative paths corresponding to each UUID value | — |
| `com_apple_xcode_dsym_uuids` | dSYM UUIDs | UUID values for all CPU types and subtypes in a dSYM bundle | — |
| `com_blackmagic_design_braw_movie_clip_anamorphic` | Anamorphic | — | — |
| `com_blackmagic_design_braw_movie_clip_braw_compression_ratio` | Compression Ratio | — | — |
| `com_blackmagic_design_braw_movie_clip_camera_type` | Camera Type | — | — |
| `com_blackmagic_design_braw_movie_clip_firmware_version` | Camera Firmware Version | — | — |
| `com_blackmagic_design_braw_movie_clip_lens_type` | Lens Type | — | — |
| `com_blackmagic_design_braw_movie_clip_resolution` | Clip Resolution | — | — |
| `com_blackmagic_design_braw_movie_clip_rotation` | Rotation | — | — |
| `com_blackmagic_design_braw_movie_clip_sensor_area_captured` | Sensor Area Captured | — | — |
| `com_blackmagic_design_braw_movie_frame0_aperture` | Aperture | — | — |
| `com_blackmagic_design_braw_movie_frame0_focal_length` | Focal Length | — | — |
| `com_blackmagic_design_braw_movie_frame0_internal_nd` | Internal ND | — | — |
| `com_blackmagic_design_braw_movie_frame0_iso` | ISO | — | — |
| `com_blackmagic_design_braw_movie_frame0_sensor_rate` | Sensor Rate | — | — |
| `com_blackmagic_design_braw_movie_frame0_shutter_value` | Shutter | — | — |
| `com_blackmagic_design_braw_movie_frame0_white_balance_kelvin` | White Balance Kelvin | — | — |
| `com_blackmagic_design_braw_movie_frame0_white_balance_tint` | White Balance Tint | — | — |
| `kMDItemAccountIdentifier` | — | — | — |
| `kMDItemAcquisitionMake` | Device make | Make of the device used to acquire this document | make |
| `kMDItemAcquisitionModel` | Device model | Model of the device used to acquire this document | model |
| `kMDItemAdditionalRecipientEmailAddresses` | — | — | — |
| `kMDItemAlbum` | Album | Title for a collection of media, such as a record album | album, title |
| `kMDItemAlternateNames` | Alternate display names | Alternate names of the file | — |
| `kMDItemAltitude` | Altitude | The altitude of the item in meters above sea level, expressed using the WGS84 datum. Negative values lie below sea level. | altitude |
| `kMDItemAperture` | Aperture value | Size of the lens aperture as a log-scale APEX value | aperture, fstop |
| `kMDItemAppStoreCategory` | Category | App Store Category item is a member of | category |
| `kMDItemAppStoreCategoryType` | — | — | — |
| `kMDItemAppleLoopDescriptors` | Loop descriptors | Keywords describing the mood and other aspects of the loop | — |
| `kMDItemAppleLoopsKeyFilterType` | Loop scale type | Whether the loop uses the major or minor scale, neither scale, or can be used with both | — |
| `kMDItemAppleLoopsLoopMode` | Loop file type | Whether the file is a looping or non-looping file. Looping files adjust their tempo to the song tempo, while non-looping files keep their recorded tempo | — |
| `kMDItemAppleLoopsRootKey` | Loop original key | Shows the loop’s original key. The key is the root note or tonic for the loop, and does not include the scale type | — |
| `kMDItemApplicationCategories` | Application Categories | Categories application is a member of | categories |
| `kMDItemAttributeChangeDate` | — | — | — |
| `kMDItemAudiences` | Audiences | Who the document is intended for | to, audience |
| `kMDItemAudioBitRate` | Audio bit rate | Bit rate of the audio in the media | audiobitrate, bitrate |
| `kMDItemAudioChannelCount` | Audio channels | Number of channels in the file’s audio data | channels |
| `kMDItemAudioEncodingApplication` | Audio encoding application | Name of the application that encoded the data in the audio file | encoder, encodedby, audioencodingapplication |
| `kMDItemAudioSampleRate` | Sample rate | Sample rate of the file’s audio data | audiosamplerate, samplerate |
| `kMDItemAudioTrackNumber` | Track number | Track number of the song that is part of an album | tracknumber |
| `kMDItemAuthorAddresses` | Author addresses | Addresses for authors of this item | from |
| `kMDItemAuthorContactIdentifiers` | — | — | — |
| `kMDItemAuthorEmailAddresses` | Author Email addresses | Email addresses for authors of this item | from, email, mail |
| `kMDItemAuthors` | Authors | Authors of this item | from, author, with, by |
| `kMDItemBitsPerSample` | Bits per sample | Number of bits per sample | bitspersample, bps |
| `kMDItemBundleIdentifier` | — | — | — |
| `kMDItemCFBundleIdentifier` | — | — | — |
| `kMDItemCalendarDelegateIdentifier` | — | — | — |
| `kMDItemCalendarHolidayIdentifier` | — | — | — |
| `kMDItemCity` | City | City of the item | city |
| `kMDItemCodecs` | Codecs | Codecs used to encode and decode the media | codec |
| `kMDItemColorSpace` | Color space | Color space model of this image | colorspace |
| `kMDItemComment` | Comment | Comments about this item | comment |
| `kMDItemComposer` | Composer | Composer of the song in the audio file | by, composer, author |
| `kMDItemContactKeywords` | Contact keywords | Contacts associated with this item | contact, contactkeyword, keyword |
| `kMDItemContentCreationDate` | Content created | Date when the content of this item was created | contentcreated, created, date |
| `kMDItemContentModificationDate` | Content modified | Date when the content of this item was modified | contentmodified, modified, date |
| `kMDItemContentType` | — | — | — |
| `kMDItemContentTypeTree` | — | — | — |
| `kMDItemContributors` | Contributors | People or organizations contributing to the content of the document | by, contributor, author, with |
| `kMDItemCopyright` | Copyright | Copyright information about this item | copyright |
| `kMDItemCountry` | Region | Country, region, or location where the item was created according to the provider | country, region |
| `kMDItemCoverage` | Coverage | Extent or scope of the content of the document | coverage |
| `kMDItemCreator` | Content Creator | Application used to create the document | creator |
| `kMDItemDateAdded` | Date added | Date when this item was last moved | dateadded, added, date |
| `kMDItemDeliveryType` | Delivery type | Method used to deliver the media (Fast Start or RTSP) | delivery |
| `kMDItemDescription` | Description | Description of the content of the document | description, comment |
| `kMDItemDestinationRecipients` | — | — | — |
| `kMDItemDirector` | Director | Director | — |
| `kMDItemDisableSearchInSpotlight` | — | — | — |
| `kMDItemDisplayName` | Display name | Localized name of the file | name, displayname |
| `kMDItemDocumentContainer` | Document Container | Containing folder of item | container |
| `kMDItemDocumentLineage` | — | — | — |
| `kMDItemDueDate` | Due date | Date this item is due | duedate, date |
| `kMDItemDurationSeconds` | Duration | Duration of this item in seconds | duration, time |
| `kMDItemEXIFGPSVersion` | EXIF GPS version | The version of GPSInfoIFD in EXIF used to generate the metadata | — |
| `kMDItemEXIFVersion` | EXIF version | Version of EXIF used to generate the metadata | exifversion |
| `kMDItemEditors` | Editors | Editors of this item | editor |
| `kMDItemEmailAddresses` | Email addresses | Email addresses associated with this item | email, mail |
| `kMDItemEmailCategory` | — | — | — |
| `kMDItemEmailConversationID` | Conversation ID | The conversation ID assigned to the message | — |
| `kMDItemEmbeddingVersion` | — | — | — |
| `kMDItemEncodingApplications` | Encoding software | Software used to convert the original content | encoder, encodedby, encodingapplication |
| `kMDItemEndDate` | End date | Date this item ends | enddate, date |
| `kMDItemExecutableArchitectures` | Executable Architectures | Architectures the item requires to execute | architectures |
| `kMDItemExecutablePlatform` | Executable Platform | Platform the item requires to execute | platform |
| `kMDItemExposureMode` | Exposure mode | Mode used for the exposure | exposuremode |
| `kMDItemExposureProgram` | Exposure program | Type of program used by the camera to set the exposure: Manual, Normal, Aperture priority, … | exposure, exposureprogram |
| `kMDItemExposureTimeSeconds` | Exposure time | Time the lens was open during exposure | exposuretime, time |
| `kMDItemFNumber` | F number | Focal length of the lens divided by the diameter of the aperture | fnumber, fstop |
| `kMDItemFSContentChangeDate` | Modified | Date the file content was last changed | modified |
| `kMDItemFSCreationDate` | Created | Date the file was created | created |
| `kMDItemFSExists` | — | — | — |
| `kMDItemFSHasCustomIcon` | Custom Icon | Whether the file has a custom icon | — |
| `kMDItemFSInvisible` | File invisible | Whether the file is visible | invisible |
| `kMDItemFSIsExtensionHidden` | File extension hidden | Whether the file extension is hidden | — |
| `kMDItemFSIsReadable` | — | — | — |
| `kMDItemFSIsStationery` | Stationery | Whether the file is stationery | stationery |
| `kMDItemFSIsWriteable` | — | — | — |
| `kMDItemFSLabel` | File label | Finder label assigned to the file | — |
| `kMDItemFSName` | Filename | Name of the file | filename |
| `kMDItemFSNodeCount` | Number of items | Number of files and folders in the folder | — |
| `kMDItemFSOwnerGroupID` | Group | Group ID of owner of the file | group |
| `kMDItemFSOwnerUserID` | Owner | User ID of the owner of the file | owner |
| `kMDItemFSSize` | File size | Logical size of the file on disk in bytes | size |
| `kMDItemFinderComment` | Spotlight comment | Spotlight comment for this item | comment, spotlightcomment |
| `kMDItemFinderOpenDate` | — | — | — |
| `kMDItemFlashOnOff` | Flash | Whether the picture was taken using a flash | flash |
| `kMDItemFocalLength` | Focal length | Focal length of the lens in millimeters (mm) | focallength |
| `kMDItemFonts` | Fonts | Fonts used in this item | font |
| `kMDItemGenre` | Genre | Genre | — |
| `kMDItemHasAlphaChannel` | Alpha channel | Whether the image has an Alpha channel | alpha |
| `kMDItemHeadline` | Headline | Publishable summary of the contents of the item | headline, title |
| `kMDItemHiddenAdditionalRecipientEmailAddresses` | — | — | — |
| `kMDItemISOSpeed` | ISO speed | ISO speed of the camera when the picture was taken | iso |
| `kMDItemIdentifier` | Identifier | Reference to a resource within a given context | id |
| `kMDItemInformation` | Movie information | Movie information | — |
| `kMDItemInstantMessageAddresses` | Instant message addresses | Instant message addresses associated with this item | chat, imname |
| `kMDItemInstructions` | Instructions | Other information concerning the item, such as handling instructions | instructions |
| `kMDItemIsApplicationManaged` | Is Application Managed | The file is owned and managed by an application | appmanaged |
| `kMDItemIsGeneralMIDISequence` | General MIDI sequence | Whether the MIDI sequence contained in the file is setup for use with a General MIDI device | ismidi |
| `kMDItemIsLikelyJunk` | Is Junk | Whether the file is likely to be considered a junk file | isjunk |
| `kMDItemIsPriority` | — | — | — |
| `kMDItemIsQuarantined` | — | — | — |
| `kMDItemIsScreenCapture` | — | — | — |
| `kMDItemIsTimeSensitive` | — | — | — |
| `kMDItemKeySignature` | Key signature | Musical key of the song in the audio file | key, keysignature |
| `kMDItemKeyphraseConfidences` | — | — | — |
| `kMDItemKeyphraseLabels` | — | — | — |
| `kMDItemKeyphraseVersion` | — | — | — |
| `kMDItemKeywords` | Keywords | Keywords associated with this item | keyword |
| `kMDItemKind` | Kind | Kind of this item | kind |
| `kMDItemLanguages` | Languages | Languages of the content of the document | language |
| `kMDItemLastUsedDate` | Last opened | Date when this item was last used | lastused, date |
| `kMDItemLatitude` | Latitude | The latitude of the item in degrees north of the equator, expressed using the WGS84 datum. Negative values lie south of the equator. | latitude |
| `kMDItemLayerNames` | Layers | Names of the layers in the file | layer |
| `kMDItemLensModel` | Lens model | Model of the lens used to acquire this document | lens |
| `kMDItemLogicSongAlternatives` | Alternatives | Alternatives contained in Logic project | — |
| `kMDItemLogicSongUsedAudioFiles` | Used Audio Files | Audio Files used by Logic project | — |
| `kMDItemLogicSongUsedEXSInstruments` | Used Sampler Instruments | Sampler Instruments used by Logic project | — |
| `kMDItemLogicSongUsedImpulseResponses` | Used Impulse Responses | Impulse Responses used by Logic project | — |
| `kMDItemLogicSongUsedUltrabeatFiles` | Used Ultrabeat Audio Files | Audio Files used by Ultrabeat within Logic project | — |
| `kMDItemLogicSongUsedVideoFiles` | Used Video Files | Video Files used by Logic project | — |
| `kMDItemLogicalSize` | Logical size | Logical size of the item in bytes | — |
| `kMDItemLongitude` | Longitude | The longitude of the item in degrees east of the prime meridian, expressed using the WGS84 datum. Negative values lie west of the prime meridian. | longitude |
| `kMDItemLyricist` | Lyricist | Lyricist of the song in the audio file | by, lyricist, author |
| `kMDItemMailboxes` | — | — | — |
| `kMDItemMaxAperture` | Max aperture | Smallest F number of the lens in APEX value units, usually in the range of 00.00 to 99.99 | maxaperture |
| `kMDItemMediaAnalysTimeRangeData` | — | — | — |
| `kMDItemMediaExtensions` | Media extensions | Media extensions used to decode the media | extensions |
| `kMDItemMediaTypes` | Media types | Media types present in the content | media, contains, mediatype |
| `kMDItemMeteringMode` | Metering mode | The metering mode (Unknown, Average, CenterWeightedAverage, Spot, MultiSpot, Pattern, Partial) | metering, meteringmode |
| `kMDItemMusicalGenre` | Musical genre | Musical genre of the song in the audio file | genre, musicalgenre |
| `kMDItemMusicalInstrumentCategory` | Instrument category | Instrument category to which the file belongs | instrument, instrumentcategory |
| `kMDItemMusicalInstrumentName` | Instrument name | Name of instrument relative to the instrument category | instrument, instrumentname |
| `kMDItemNamedLocation` | Location | Name of the location or point of interest | location |
| `kMDItemNumberOfPages` | Pages | Number of pages in the document | pages |
| `kMDItemOrganizations` | Organizations | Organizations that created the document | organization |
| `kMDItemOrientation` | Orientation | Orientation of the picture (landscape or portrait) | orientation |
| `kMDItemOriginApplicationIdentifier` | — | — | — |
| `kMDItemOriginMessageIDkMDItemOriginMessageID` | — | — | — |
| `kMDItemOriginSenderDisplayName` | — | — | — |
| `kMDItemOriginSenderHandle` | — | — | — |
| `kMDItemOriginSubject` | — | — | — |
| `kMDItemOriginalFormat` | Original Format | Original Format | — |
| `kMDItemOriginalSource` | Original Source | Original Source | — |
| `kMDItemPageHeight` | Page height | Height of the document page in points | pageheight, height |
| `kMDItemPageWidth` | Page width | Width of the document page in points | pagewidth, width |
| `kMDItemParticipants` | Participants | Participants in this item | — |
| `kMDItemPath` | File pathname | Complete pathname of this file | path |
| `kMDItemPerformers` | Performers | Performers | — |
| `kMDItemPhoneNumbers` | Phone number | Phone numbers associated with this item | phone, phonenumber |
| `kMDItemPhysicalSize` | Physical size | Physical size of the item in bytes | — |
| `kMDItemPixelCount` | Pixel count | Total number of pixels in the document | pixelcount |
| `kMDItemPixelHeight` | Pixel height | Height of the document in pixels | pixelheight, height |
| `kMDItemPixelWidth` | Pixel width | Width of the document in pixels | pixelwidth, width |
| `kMDItemPrimaryRecipientEmailAddresses` | — | — | — |
| `kMDItemPriorityStatus` | — | — | — |
| `kMDItemProducer` | Producer | Producer of this item | producer |
| `kMDItemProfileName` | Color profile | Name of the color profile used for the image | profile |
| `kMDItemProjects` | Projects | Projects this item is part of | — |
| `kMDItemPublishers` | Publishers | Publisher of the document | publisher |
| `kMDItemPurchaseDate` | Purchase Date | Date this item was purchased | purchasedate |
| `kMDItemRecipientAddresses` | Recipient addresses | Addresses for recipients of this item | to |
| `kMDItemRecipientContactIdentifiers` | — | — | — |
| `kMDItemRecipientEmailAddresses` | Recipient Email addresses | Email addresses for recipients of this item | to, email, mail |
| `kMDItemRecipients` | Recipients | Recipients of this item | to, recipient, with |
| `kMDItemRecordingDate` | Recording date | Date the song was recorded | recordingdate, date |
| `kMDItemRecordingYear` | Year recorded | Year the item was recorded | yearrecorded, year |
| `kMDItemRedEyeOnOff` | Red eye | Whether ‘red eye’ correction was on or off | redeye |
| `kMDItemRelatedUniqueIdentifier` | — | — | — |
| `kMDItemResolutionHeightDPI` | Resolution height | Resolution height of this image in DPI | heightdpi, dpi |
| `kMDItemResolutionWidthDPI` | Resolution width | Resolution width of this image in DPI | widthdpi, dpi |
| `kMDItemRights` | Rights | Link to information about the rights held on the document | rights |
| `kMDItemScreenCaptureType` | — | — | — |
| `kMDItemSecurityMethod` | Security | Encryption method used to make the document secure | security, securitymethod |
| `kMDItemStarRating` | Rating | User Rating | starrating |
| `kMDItemStartDate` | Start date | Date this item starts | startdate, date |
| `kMDItemStateOrProvince` | State or Province | State or province of the item according to the provider | state, province |
| `kMDItemStreamable` | Streamable | Whether the content is prepared for streaming | streamable |
| `kMDItemSubject` | Subject | Subject of this item | subject, title, name |
| `kMDItemSupportFileType` | — | — | — |
| `kMDItemTempo` | Tempo | Tempo of the music in the audio file in Beats Per Minute | tempo |
| `kMDItemTextContent` | Text content | Text content of this item | content, contains, intext |
| `kMDItemTextContentSummary` | — | — | — |
| `kMDItemTextVector` | — | — | — |
| `kMDItemTheme` | Theme | Theme of this item | theme |
| `kMDItemTimeSignature` | Time signature | Time signature of the song in the audio or MIDI file | timesignature |
| `kMDItemTitle` | Title | Title of this item | title |
| `kMDItemTotalBitRate` | Total bit rate | Combined bit rate of the audio and video in the media | totalbitrate, bitrate |
| `kMDItemURL` | URL | URL of this item | url |
| `kMDItemUsedDates` | Used dates | Dates when this item was used | used, date |
| `kMDItemUserCreatedDate` | — | — | — |
| `kMDItemUserCreatedUserHandle` | — | — | — |
| `kMDItemUserDownloadedDate` | — | — | — |
| `kMDItemUserDownloadedUserHandle` | — | — | — |
| `kMDItemUserModifiedDate` | — | — | — |
| `kMDItemUserModifiedUserHandle` | — | — | — |
| `kMDItemUserPrintedDate` | — | — | — |
| `kMDItemUserPrintedUserHandle` | — | — | — |
| `kMDItemUserSharedReceivedDate` | — | — | — |
| `kMDItemUserSharedReceivedRecipient` | — | — | — |
| `kMDItemUserSharedReceivedRecipientHandle` | — | — | — |
| `kMDItemUserSharedReceivedSender` | — | — | — |
| `kMDItemUserSharedReceivedSenderHandle` | — | — | — |
| `kMDItemUserSharedReceivedTransport` | — | — | — |
| `kMDItemUserSharedSentDate` | — | — | — |
| `kMDItemUserSharedSentRecipient` | — | — | — |
| `kMDItemUserSharedSentRecipientHandle` | — | — | — |
| `kMDItemUserSharedSentSender` | — | — | — |
| `kMDItemUserSharedSentSenderHandle` | — | — | — |
| `kMDItemUserSharedSentTransport` | — | — | — |
| `kMDItemUserTags` | Tags | Tags associated with this item | tag |
| `kMDItemVersion` | Version | Version number of this item | version |
| `kMDItemVideoBitRate` | Video bit rate | Bit rate of the video in the media | videobitrate, bitrate |
| `kMDItemWeakRelatedUniqueIdentifier` | — | — | — |
| `kMDItemWhereFroms` | Where from | Where the item came from | from, source, wherefrom |
| `kMDItemWhiteBalance` | White balance | White balance setting of the camera when the picture was taken | whitebalance |
| `kMDItemXMPCredit` | Credit | Photo metadata credit line | xmpCredit |
| `kMDItemXMPDigitalSourceType` | Content Creator | Photo metadata digital source type | xmpDigitalSourceType |


## Refreshing this catalog

Because the registry changes with macOS and installed software, regenerate or compare the live list with `mdimport -A`. The catalog above is a snapshot, not a compatibility promise. For portable scripts, use documented `kMDItem…` attributes, tolerate nulls, and test on every supported macOS release.

## Related commands

- `mdfind(1)` searches the Spotlight metadata store.
- `mdimport(1)` inspects importers and the active metadata schema.
- `mdutil(1)` manages and reports Spotlight indexing status.
- `plutil(1)` reads property lists directly and is preferable for exact bundle keys.
- `xattr(1)` reads filesystem extended attributes; those are distinct from Spotlight metadata.

## Local sources

This reference was derived from the local `mdls(1)` and `mdimport(1)` manual pages and the active `mdimport -A` registry on the system identified above.
