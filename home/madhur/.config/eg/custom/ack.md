Find word within source files
    ack src

Find within particular file types
    find . -name '*.go' | ack -x 'VTDATAROOT'  


Similar to other
    ack --go 'VTDATAROOT' 

View list of file types
    ack --help-types
