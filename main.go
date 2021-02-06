package main

import (
	"fmt"
	"net/http"
)

func main() {
	http.HandleFunc("/", Server)
	http.ListenAndServe(":80", nil)
}

func Server(w http.ResponseWriter, r *http.Request) {
	fmt.Fprint(w, "Hello zapp")
}
