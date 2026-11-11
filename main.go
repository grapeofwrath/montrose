package main

import (
	"encoding/json"
	"log"
	"os"
	"path/filepath"
	"strings"

	"net/http"

	"github.com/a-h/templ"
	"github.com/labstack/echo/v5"
	"github.com/labstack/echo/v5/middleware"

	"montRose/views"
)

const reviewsPath = "public/assets/reviews.json"

func render(c *echo.Context, status int, t templ.Component) error {
	buf := templ.GetBuffer()
	defer templ.ReleaseBuffer(buf)

	if err := t.Render(c.Request().Context(), buf); err != nil {
		return err
	}
	return c.HTML(status, buf.String())
}

// A missing or malformed file is logged and the page renders without reviews.
func loadReviews(path string) []views.Review {
	data, err := os.ReadFile(path)
	if err != nil {
		log.Printf("reviews: %v", err)
		return nil
	}
	var reviews []views.Review
	if err := json.Unmarshal(data, &reviews); err != nil {
		log.Printf("reviews: parsing %s: %v", path, err)
		return nil
	}
	return reviews
}

func homeHandler(c *echo.Context) error {
	return render(c, http.StatusOK, views.Home(loadReviews(reviewsPath)))
}

func galleryHandler(c *echo.Context) error {
	entries, err := os.ReadDir("public/images")
	if err != nil {
		return err
	}

	var images []views.Image
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		switch strings.ToLower(filepath.Ext(e.Name())) {
		case ".jpg", ".jpeg", ".png", ".webp":
			images = append(images, views.Image{
				Src: "/images/" + e.Name(),
				Alt: "Finish carpentry project photo",
				Num: len(images) + 1,
			})
		}
	}

	return render(c, http.StatusOK, views.Gallery(images))
}

func main() {
	e := echo.New()

	e.Use(middleware.StaticWithConfig(middleware.StaticConfig{
		Root:                 "public",
		EnablePathUnescaping: false,
	}))

	e.GET("/", homeHandler)
	e.GET("/gallery", galleryHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "5050"
	}
	if err := e.Start(":"+port); err != nil {
		e.Logger.Error("server stopped", "error", err)
	}
}
