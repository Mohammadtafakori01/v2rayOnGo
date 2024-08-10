package main

import (
    "fmt"
    "io/ioutil"
    "log"
    "net/http"
    "os/exec"
    "strconv"
    "strings"
)

// BasicAuthMiddleware is a middleware for basic authentication
func BasicAuthMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        username, password, ok := r.BasicAuth()
        if !ok || username != "admin" || password != "7578808757#Config" {
            w.Header().Set("WWW-Authenticate", `Basic realm="restricted"`)
            http.Error(w, "Unauthorized", http.StatusUnauthorized)
            return
        }
        next.ServeHTTP(w, r)
    })
}

// getLastPort reads the last used port from the file
func getLastPort() (int, error) {
    data, err := ioutil.ReadFile("lastPort")
    if err != nil {
        return 0, err
    }
    port, err := strconv.Atoi(strings.TrimSpace(string(data)))
    if err != nil {
        return 0, err
    }
    return port, nil
}

// saveLastPort saves the last used port to the file
func saveLastPort(port int) error {
    return ioutil.WriteFile("lastPort", []byte(fmt.Sprintf("%d", port)), 0644)
}

// createConfigHandler runs the shell script
func createConfigHandler(w http.ResponseWriter, r *http.Request) {
    // Get the last used port and increment it
    port, err := getLastPort()
    if err != nil {
        log.Println("Error reading last port:", err)
        http.Error(w, "Error reading last port", http.StatusInternalServerError)
        return
    }
    port++

    // Save the new port
    if err := saveLastPort(port); err != nil {
        log.Println("Error saving last port:", err)
        http.Error(w, "Error saving last port", http.StatusInternalServerError)
        return
    }

    // Run the shell script with the new port
    cmd := exec.Command("/bin/bash", "script.sh", strconv.Itoa(port))
    output, err := cmd.CombinedOutput()
    if err != nil {
        log.Println("Error executing script:", err)
        http.Error(w, fmt.Sprintf("Error executing script: %v", err), http.StatusInternalServerError)
        return
    }

    // Respond with the script output
    w.WriteHeader(http.StatusOK)
    w.Write(output)
}

func main() {
    mux := http.NewServeMux()
    mux.Handle("/createConfig", BasicAuthMiddleware(http.HandlerFunc(createConfigHandler)))

    server := &http.Server{
        Addr:    ":8080",
        Handler: mux,
    }

    log.Println("Starting server on :8080")
    if err := server.ListenAndServe(); err != nil {
        log.Fatalf("Server failed: %v", err)
    }
}
