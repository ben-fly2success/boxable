function BoxFileInput(file_input) {
    var dst_field = $(`#${file_input}`).data('dst-field');
    var overwrite = true; // Set to false to prevent overwriting in case of conflicts
    var fileUploaded = false;

    var showUploader = function(e) {
        myModal = $('#exampleModal');
        fileName = e.dataset.fileName;
        fileField = e.dataset.index;
        myModal.modal('show');
    };

    $(`#${file_input}`).on('input', function () {
        if ($(`#${file_input}`).prop('files').length > 0) {
            upload();
        };
    });

    /**
     * Resets the file input
     *
     * @return {void}
     */
    var clearFileInput = function() {
        $(`#${file_input}`).val('');
    };

    /**
     * Handles a generic upload error like 401.
     * It is not guaranteed that the error will be 401.
     *
     * @return {void}
     */
    var handleGenericError = function() {
        clearFileInput();
        alert('Auth token likely busted!');
    };

    /**
     * Handles the upload rate limiting
     *
     * @param {Promise} Fetch response json data promise
     * @return {void}
     */
    var handleRateLimit = function(json) {
        // do something json.then(...)
        // Or throw some error about rate limiting
    };

    /**
     * Handles the upload conflict
     *
     * @param {Promise} Fetch response json data promise
     * @return {void}
     */
    var handleConflict = function(json) {
        if (overwrite) {
            json.then(({ context_info }) => {
                upload(context_info.conflicts.id);
            });
        } else {
            // throw some error about conflicts
        }
    };

    /**
     * Handles the folder upload response
     *
     * @param {Response} Fetch response object
     * @return {void}
     */
    var uploadHandler = function(response) {
        const { status } = response;
        console.log(response);
        if (status >= 200 && status < 300) {
            response.json().then(function(json) {
                fileUploaded = true;
                $(`#${dst_field}`).val(json.entries[0]['id']);
                console.log(`#${dst_field}`);
            });            // Upload was successful
            $(`#${file_input}`).val('');
            clearFileInput();
            return;
        }

        // Handle errors
        switch (status) {
            case 409:
                handleConflict(response.json());
                break;
            case 429:
                handleRateLimit(response.json());
                break;
            default:
                handleGenericError();
                break;
        };
    }

    /**
     * Uploads a file.
     *
     * @param {string|void} [fileId] optional file id to resolve conflicts against
     * @return {void}
     */
    var upload = function(file_id) {
        $(`#${dst_field}`).val(null);

        const formData = new FormData();
        const file = $(`#${file_input}`).prop('files')[0];
        var fileSplit = file.name.split('.');
        var fileExt = fileSplit[fileSplit.length - 1];
        const attributes = JSON.stringify({
            name: uuidv4() + '.' + fileExt,
            parent: { id: boxable.temp_folder.id() }
        });

        formData.append('file', file);
        formData.append('attributes', attributes);

        let url = 'https://upload.box.com/api/2.0/files/content';
        if (file_id) {
            url = url.replace('content', `${file_id}/content`);
        }

        const options = {
            method: 'post',
            headers: {
                Authorization: `Bearer ${boxable.temp_folder.token()}`
            },
            body: formData,
            credentials: 'same-origin'
        };

        fetch(url, options)
            .then(uploadHandler)
            .catch(uploadHandler);
    }
}

const Boxable = function() {
    this.BoxFolder = function(url) {
        /* Hash with attributes:
            - folder: Box folder id
            - token: Token to access the folder
            - expire_at: Date on which the token will expire
        */
        var data = null;

        // Refresh data content by asking the server for new metadata
        var update_folder = function() {
            $.ajax({url: url,
                success: function(got_data) {
                    data = got_data;
                }});
        };

        // Returns true if folder metadata is valid, false if invalid
        var is_folder_valid = function() {
            if (!data)
                return false;
            return new Date(data['expire_at']) - Date.now() > 0;
        };

        // Read folder metadata
        var folder_attr = function(attr) {
            // Refresh folder metadata until it is valid
            while (!is_folder_valid())
                update_folder();
            return data[attr];
        };

        this.token = function() {
            return folder_attr('token');
        };
        this.id = function() {
            return folder_attr('folder');
        };

        // Refresh data on creation to avoid latency on first upload
        update_folder();
    };

    // Function to call whenever new DOM elements are inserted into the page
    this.refreshDOM = function() {
        $('.box-file-input').each(function(i, el) {
            if ($(el).data('init'))
                return;
            new BoxFileInput($(el).attr('id'));
            $(el).data('init', true);
        });
    };

    // Temporary folder metadata
    this.temp_folder = new this.BoxFolder('/box_tokens/temp');
};

boxable = new Boxable();