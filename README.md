# Boxable

A gem helping you managing a Box file tree in your Ruby on Rails application.

## Usage

### Model declaration

To indicate a model should have a Box folder attached, just call `acts_as_boxable` on your class declaration.
#### acts_as_boxable options
- **name**: The name of the method to call to get the created folder name. By default, **slug** will be called.
- **parent**: The name of the boxable association in which the folder is located. Make sure it has **inverse_of** defined, so the library knows which name to use for the sub folder.
- **folder**: The folder mode to use. By default, an exclusive folder will be created for each new record. You can set this option to **:common** to use the folder dedicated to the association, or even **:parent** to use parent's folder. Make sure you don't have name clashes using those options.

Box folders will automatically be created when needed, and destroyed with the record.

_Note_: Specifying has_many of boxable elements will also generate appropriate sub folders for the record.

### Additional attachments

`has_one_box_file(name)`: every instance of the model can have a Box file attached. Default value is nil, as for Rails has_one associations.
To attach a file, use `instance.file = your_box_file_id`.
The Box file ID will be located in `instance.file.file_id`. The URL of the file in `instance.file.url`.
To detach it, you use `instance.file.destroy`.
You can use the option **name_method** to specify what method of the instance should be called to set the actual name of the file in Box.

_Note:_ The file attachment will be destroyed from Box on owner destruction.

`has_one_box_folder(name)`: an additionnal folder for the record will be created. Calling `instance.folder` will give you a **BoxFolder** record, which can be used to store additional data (see **add_file** method of BoxFolder instances).

`has_one_box_picture(name)`: stores a picture in Box. You can attach and detach a picture the same way you attach a file. Behind the scenes, it will create a folder for the picture, where files with various definitions will be stored. Today the only file being saved is the original picture, to the future it is planned to be able to specify various resolutions to downsize the image on saving.

### Misc

- To get the _BoxFolder_ record of the object, call **box_folder** on it. You can pass the name of an attribute (e.g. _has_many_ boxable association) to get the sub folder record.
- Use **box_folder_id** to directly get the ID of the folder.
