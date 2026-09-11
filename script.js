/* =========================================================
   MOR PANCHAYAT WEBSITE
   Lightweight / Performance Optimized
   ========================================================= */


/* =========================================================
   1. GITHUB CONFIG
========================================================= */

const GITHUB_OWNER = "Anshu101com";
const GITHUB_REPO = "mor-panchayat";

const GITHUB_API =
    `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases`;

const GITHUB_RELEASES_PAGE =
    `https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases`;

const GITHUB_REPOSITORY_PAGE =
    `https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}`;


/* =========================================================
   2. DOM ELEMENTS
========================================================= */

const elements = {
    navbar: document.getElementById("navbar"),

    menuButton: document.getElementById("menuButton"),
    navLinks: document.getElementById("navLinks"),

    heroVersion: document.getElementById("heroVersion"),

    latestVersion:
        document.getElementById("latestVersion"),

    latestReleaseDescription:
        document.getElementById("latestReleaseDescription"),

    latestReleaseDate:
        document.getElementById("latestReleaseDate"),

    downloadVersion:
        document.getElementById("downloadVersion"),

    downloadDate:
        document.getElementById("downloadDate"),

    downloadFile:
        document.getElementById("downloadFile"),

    downloadButton:
        document.getElementById("downloadButton"),

    qrContainer:
        document.getElementById("qrContainer"),

    qrVersion:
        document.getElementById("qrVersion"),

    releasesList:
        document.getElementById("releasesList"),

    releasesError:
        document.getElementById("releasesError"),

    retryReleases:
        document.getElementById("retryReleases"),

    githubReleasesLink:
        document.getElementById("githubReleasesLink"),

    footerGithubLink:
        document.getElementById("footerGithubLink"),

    footerVersion:
        document.getElementById("footerVersion"),

    currentYear:
        document.getElementById("currentYear"),

    backToTop:
        document.getElementById("backToTop")
};


/* =========================================================
   3. STATE
========================================================= */

let releases = [];
let latestRelease = null;
let latestAPK = null;

let releaseRequestRunning = false;

let lastReleaseCheck = 0;

const RELEASE_CACHE_TIME =
    5 * 60 * 1000;


/* =========================================================
   4. INITIALIZATION
========================================================= */

document.addEventListener(
    "DOMContentLoaded",
    initializeWebsite
);


async function initializeWebsite() {

    setCurrentYear();

    setupNavigation();

    setupScrollEffects();

    setupBackToTop();

    setupSmoothLinks();

    setupRetryButton();

    setGitHubLinks();

    await loadGitHubReleases();

}


/* =========================================================
   5. CURRENT YEAR
========================================================= */

function setCurrentYear() {

    if (!elements.currentYear) {
        return;
    }

    elements.currentYear.textContent =
        new Date().getFullYear();

}


/* =========================================================
   6. NAVIGATION
========================================================= */

function setupNavigation() {

    if (
        !elements.menuButton ||
        !elements.navLinks
    ) {
        return;
    }

    elements.menuButton.addEventListener(
        "click",
        () => {

            const isOpen =
                elements.navLinks.classList.toggle("open");

            elements.menuButton.classList.toggle(
                "open",
                isOpen
            );

            elements.menuButton.setAttribute(
                "aria-expanded",
                String(isOpen)
            );

        }
    );


    const links =
        elements.navLinks.querySelectorAll(".nav-link");


    links.forEach(link => {

        link.addEventListener(
            "click",
            () => {

                elements.navLinks.classList.remove("open");

                elements.menuButton.classList.remove("open");

                elements.menuButton.setAttribute(
                    "aria-expanded",
                    "false"
                );

            }
        );

    });

}


/* =========================================================
   7. SCROLL EFFECTS
   Uses requestAnimationFrame to avoid excessive work
========================================================= */

function setupScrollEffects() {

    updateNavbar();

    updateActiveNavigation();


    let ticking = false;


    window.addEventListener(
        "scroll",
        () => {

            if (ticking) {
                return;
            }

            ticking = true;


            requestAnimationFrame(() => {

                updateNavbar();

                updateActiveNavigation();

                ticking = false;

            });

        },
        {
            passive: true
        }
    );

}


/* =========================================================
   8. NAVBAR
========================================================= */

function updateNavbar() {

    if (!elements.navbar) {
        return;
    }

    elements.navbar.classList.toggle(
        "scrolled",
        window.scrollY > 25
    );

}


/* =========================================================
   9. ACTIVE NAVIGATION
========================================================= */

function updateActiveNavigation() {

    const sections =
        document.querySelectorAll(
            "main section[id]"
        );

    const links =
        document.querySelectorAll(
            ".nav-link"
        );


    if (!sections.length || !links.length) {
        return;
    }


    let currentSection = "home";


    for (const section of sections) {

        const rect =
            section.getBoundingClientRect();


        if (
            rect.top <= 160 &&
            rect.bottom >= 160
        ) {

            currentSection =
                section.id;

            break;

        }

    }


    links.forEach(link => {

        const href =
            link.getAttribute("href");

        link.classList.toggle(
            "active",
            href === `#${currentSection}`
        );

    });

}


/* =========================================================
   10. SMOOTH LINKS
========================================================= */

function setupSmoothLinks() {

    const links =
        document.querySelectorAll(
            'a[href^="#"]'
        );


    links.forEach(link => {

        link.addEventListener(
            "click",
            event => {

                const targetID =
                    link.getAttribute("href");


                if (
                    !targetID ||
                    targetID === "#"
                ) {
                    return;
                }


                const target =
                    document.querySelector(targetID);


                if (!target) {
                    return;
                }


                event.preventDefault();


                const navbarHeight =
                    elements.navbar
                        ? elements.navbar.offsetHeight
                        : 0;


                const targetPosition =
                    target.getBoundingClientRect().top +
                    window.scrollY -
                    navbarHeight -
                    10;


                window.scrollTo({
                    top: targetPosition,
                    behavior: "smooth"
                });

            }
        );

    });

}


/* =========================================================
   11. BACK TO TOP
========================================================= */

function setupBackToTop() {

    if (!elements.backToTop) {
        return;
    }


    let ticking = false;


    window.addEventListener(
        "scroll",
        () => {

            if (ticking) {
                return;
            }

            ticking = true;


            requestAnimationFrame(() => {

                elements.backToTop.classList.toggle(
                    "visible",
                    window.scrollY > 600
                );

                ticking = false;

            });

        },
        {
            passive: true
        }
    );


    elements.backToTop.addEventListener(
        "click",
        () => {

            window.scrollTo({
                top: 0,
                behavior: "smooth"
            });

        }
    );

}


/* =========================================================
   12. GITHUB LINKS
========================================================= */

function setGitHubLinks() {

    if (
        GITHUB_OWNER === "YOUR_GITHUB_USERNAME" ||
        GITHUB_REPO === "YOUR_REPOSITORY_NAME"
    ) {

        console.warn(
            "Mor Panchayat: GitHub repository is not configured."
        );

        return;

    }


    if (elements.githubReleasesLink) {

        elements.githubReleasesLink.href =
            GITHUB_RELEASES_PAGE;

    }


    if (elements.footerGithubLink) {

        elements.footerGithubLink.href =
            GITHUB_REPOSITORY_PAGE;

    }

}


/* =========================================================
   13. LOAD GITHUB RELEASES
========================================================= */

async function loadGitHubReleases(
    force = false
) {

    if (releaseRequestRunning) {
        return;
    }


    const now = Date.now();


    if (
        !force &&
        now - lastReleaseCheck <
        RELEASE_CACHE_TIME
    ) {
        return;
    }


    if (
        GITHUB_OWNER === "YOUR_GITHUB_USERNAME" ||
        GITHUB_REPO === "YOUR_REPOSITORY_NAME"
    ) {

        showConfigurationError();

        return;

    }


    releaseRequestRunning = true;


    showReleaseLoading();


    try {

        const response =
            await fetch(
                GITHUB_API,
                {
                    method: "GET",

                    headers: {
                        "Accept":
                            "application/vnd.github+json"
                    },

                    cache: "no-store"
                }
            );


        if (!response.ok) {

            throw new Error(
                `GitHub API returned ${response.status}`
            );

        }


        const data =
            await response.json();


        if (
            !Array.isArray(data) ||
            data.length === 0
        ) {

            throw new Error(
                "No releases found."
            );

        }


        releases =
            data
                .filter(
                    release =>
                        !release.draft &&
                        !release.prerelease
                )
                .sort(sortReleases);


        if (!releases.length) {

            throw new Error(
                "No published releases found."
            );

        }


        latestRelease =
            releases[0];


        latestAPK =
            findAPK(latestRelease);


        updateLatestRelease();

        renderReleaseHistory();

        updateQRCode();


        lastReleaseCheck = Date.now();


    } catch (error) {

        console.error(
            "Mor Panchayat release loading error:",
            error
        );


        showReleaseError();

    } finally {

        releaseRequestRunning = false;

    }

}


/* =========================================================
   14. SORT RELEASES
========================================================= */

function sortReleases(a, b) {

    const dateA =
        new Date(
            a.published_at ||
            a.created_at ||
            0
        ).getTime();


    const dateB =
        new Date(
            b.published_at ||
            b.created_at ||
            0
        ).getTime();


    return dateB - dateA;

}


/* =========================================================
   15. FIND APK
========================================================= */

function findAPK(release) {

    if (
        !release ||
        !Array.isArray(release.assets)
    ) {
        return null;
    }


    const apkAssets =
        release.assets.filter(
            asset =>
                typeof asset.name === "string" &&
                asset.name
                    .toLowerCase()
                    .endsWith(".apk")
        );


    if (!apkAssets.length) {
        return null;
    }


    const preferred =
        apkAssets.find(
            asset => {

                const name =
                    asset.name.toLowerCase();

                return (
                    name.includes("release") ||
                    name.includes("universal")
                );

            }
        );


    return preferred || apkAssets[0];

}


/* =========================================================
   16. UPDATE LATEST RELEASE
========================================================= */

function updateLatestRelease() {

    if (!latestRelease) {
        return;
    }


    const version =
        getVersionName(latestRelease);


    const date =
        formatDate(
            latestRelease.published_at ||
            latestRelease.created_at
        );


    const description =
        getReleaseDescription(
            latestRelease
        );


    /* HERO */

    setText(
        elements.heroVersion,
        version
    );


    /* LATEST RELEASE */

    setText(
        elements.latestVersion,
        version
    );


    setText(
        elements.latestReleaseDate,
        date
    );


    setText(
        elements.latestReleaseDescription,
        description
    );


    /* DOWNLOAD */

    setText(
        elements.downloadVersion,
        version
    );


    setText(
        elements.downloadDate,
        date
    );


    /* FOOTER */

    setText(
        elements.footerVersion,
        version
    );


    /* QR */

    setText(
        elements.qrVersion,
        version
    );


    /* APK */

    if (latestAPK) {

        setText(
            elements.downloadFile,
            formatFileSize(latestAPK.size)
        );


        if (elements.downloadButton) {

            elements.downloadButton.href =
                latestAPK.browser_download_url;

            elements.downloadButton.target = "_self";
            
            elements.downloadButton.removeAttribute("rel");

            elements.downloadButton.setAttribute("download", "");

            elements.downloadButton.classList.remove(
                "disabled"
            );

            elements.downloadButton.innerHTML = `
                <span class="download-button-icon">
                    ↓
                </span>

                <span>
                    Download APK
                </span>

                <span class="download-button-arrow">
                    →
                </span>
            `;

        }

    } else {

        setText(
            elements.downloadFile,
            "Not available"
        );


        if (elements.downloadButton) {

            elements.downloadButton.removeAttribute(
                "href"
            );

            elements.downloadButton.classList.add(
                "disabled"
            );

            elements.downloadButton.innerHTML = `
                <span class="download-button-icon">
                    ⚠
                </span>

                <span>
                    APK unavailable
                </span>
            `;

        }

    }

}


/* =========================================================
   17. VERSION NAME
========================================================= */

function getVersionName(release) {

    if (!release) {
        return "Unknown";
    }


    if (
        release.tag_name &&
        release.tag_name.trim()
    ) {

        return release.tag_name.trim();

    }


    if (
        release.name &&
        release.name.trim()
    ) {

        return release.name.trim();

    }


    return "Unknown";

}


/* =========================================================
   18. RELEASE DESCRIPTION
========================================================= */

function getReleaseDescription(release) {

    if (!release) {

        return "Latest Mor Panchayat release.";

    }


    if (
        release.body &&
        release.body.trim()
    ) {

        const clean =
            stripMarkdown(
                release.body
            );


        if (clean.length > 150) {

            return (
                clean.substring(0, 147) +
                "..."
            );

        }


        return clean;

    }


    return (
        "Latest Mor Panchayat application release."
    );

}


/* =========================================================
   19. RENDER RELEASE HISTORY
========================================================= */

function renderReleaseHistory() {

    if (!elements.releasesList) {
        return;
    }


    if (!releases.length) {

        elements.releasesList.innerHTML = "";

        return;

    }


    const fragment =
        document.createDocumentFragment();


    releases.forEach(
        (release, index) => {

            const version =
                getVersionName(release);


            const date =
                formatDate(
                    release.published_at ||
                    release.created_at
                );


            const apk =
                findAPK(release);


            const description =
                getReleaseDescription(release);


            const item =
                document.createElement("article");


            item.className =
                "release-item";


            item.innerHTML = `
                <div class="
                    release-version
                    ${index === 0 ? "latest" : ""}
                ">
                    ${escapeHTML(version)}
                </div>

                <div class="release-meta">

                    <strong>
                        ${escapeHTML(
                            release.name ||
                            "Mor Panchayat Release"
                        )}
                    </strong>

                    <span>
                        ${escapeHTML(date)}
                    </span>

                    <span>
                        ${escapeHTML(description)}
                    </span>

                </div>

                <div class="release-actions">

                    ${
                        index === 0
                        ? `
                            <span class="release-tag">
                                Latest
                            </span>
                        `
                        : ""
                    }

                    ${
                        apk
                        ? `
                            <a
                                class="release-download"
                                href="${escapeAttribute(
                                    apk.browser_download_url
                                )}"
                                download
                            >
                                ↓ Download
                            </a>
                        `
                        : `
                            <span
                                class="release-download"
                                aria-disabled="true"
                            >
                                APK unavailable
                            </span>
                        `
                    }

                </div>
            `;


            fragment.appendChild(item);

        }
    );


    elements.releasesList.innerHTML = "";

    elements.releasesList.appendChild(fragment);

}


/* =========================================================
   20. QR CODE
========================================================= */

function updateQRCode() {

    if (
        !elements.qrContainer ||
        !latestAPK
    ) {
        return;
    }


    const apkURL =
        latestAPK.browser_download_url;


    /*
       Smaller QR image = less bandwidth
       and faster loading.
    */

    const qrURL =
        `https://api.qrserver.com/v1/create-qr-code/?size=300x300&margin=8&data=${encodeURIComponent(
            apkURL
        )}`;


    elements.qrContainer.innerHTML = `
        <img
            src="${escapeAttribute(qrURL)}"
            alt="QR code to download the latest Mor Panchayat APK"
            width="300"
            height="300"
            loading="lazy"
            decoding="async"
        >
    `;

}


/* =========================================================
   21. LOADING STATE
========================================================= */

function showReleaseLoading() {

    if (!elements.releasesList) {
        return;
    }


    /*
       Don't destroy already loaded releases
       during background refresh.
    */

    if (releases.length > 0) {
        return;
    }


    elements.releasesList.innerHTML = `
        <div class="releases-loading">

            <div class="loading-spinner"></div>

            <span>
                Loading release history...
            </span>

        </div>
    `;


    if (elements.releasesError) {

        elements.releasesError.hidden = true;

    }

}


/* =========================================================
   22. ERROR STATE
========================================================= */

function showReleaseError() {

    if (elements.releasesList && !releases.length) {

        elements.releasesList.innerHTML = "";

    }


    if (elements.releasesError) {

        elements.releasesError.hidden = false;

    }


    setText(
        elements.heroVersion,
        "Unavailable"
    );


    setText(
        elements.latestVersion,
        "Unavailable"
    );


    setText(
        elements.downloadVersion,
        "Unavailable"
    );


    setText(
        elements.downloadDate,
        "—"
    );


    setText(
        elements.latestReleaseDate,
        "—"
    );


    setText(
        elements.footerVersion,
        "—"
    );


    if (elements.latestReleaseDescription) {

        elements.latestReleaseDescription.textContent =
            "Release information is temporarily unavailable.";

    }

}


/* =========================================================
   23. CONFIGURATION ERROR
========================================================= */

function showConfigurationError() {

    if (elements.releasesList) {

        elements.releasesList.innerHTML = `
            <div class="releases-error">

                <div class="error-icon">
                    ⚙
                </div>

                <h3>
                    GitHub repository not configured
                </h3>

                <p>
                    Add your GitHub username and repository
                    name at the top of script.js.
                </p>

            </div>
        `;

    }


    setText(
        elements.heroVersion,
        "Configure GitHub"
    );

}


/* =========================================================
   24. RETRY BUTTON
========================================================= */

function setupRetryButton() {

    if (!elements.retryReleases) {
        return;
    }


    elements.retryReleases.addEventListener(
        "click",
        async () => {

            if (elements.releasesError) {

                elements.releasesError.hidden =
                    true;

            }


            await loadGitHubReleases(true);

        }
    );

}


/* =========================================================
   25. DATE FORMAT
========================================================= */

function formatDate(dateString) {

    if (!dateString) {
        return "Unknown";
    }


    const date =
        new Date(dateString);


    if (
        Number.isNaN(
            date.getTime()
        )
    ) {

        return "Unknown";

    }


    return new Intl.DateTimeFormat(
        "en-IN",
        {
            day: "2-digit",
            month: "short",
            year: "numeric"
        }
    ).format(date);

}


/* =========================================================
   26. FILE SIZE
========================================================= */

function formatFileSize(bytes) {

    if (
        typeof bytes !== "number" ||
        bytes <= 0
    ) {

        return "APK";

    }


    const MB =
        bytes / (1024 * 1024);


    if (MB < 1) {

        return (
            `${Math.round(
                bytes / 1024
            )} KB`
        );

    }


    return `${MB.toFixed(1)} MB`;

}


/* =========================================================
   27. MARKDOWN CLEANER
========================================================= */

function stripMarkdown(text) {

    return text

        .replace(
            /```[\s\S]*?```/g,
            ""
        )

        .replace(
            /`([^`]+)`/g,
            "$1"
        )

        .replace(
            /!\[.*?\]\(.*?\)/g,
            ""
        )

        .replace(
            /\[([^\]]+)\]\([^)]+\)/g,
            "$1"
        )

        .replace(
            /#{1,6}\s*/g,
            ""
        )

        .replace(
            /[*_~>-]/g,
            " "
        )

        .replace(
            /\r?\n+/g,
            " "
        )

        .replace(
            /\s+/g,
            " "
        )

        .trim();

}


/* =========================================================
   28. SET TEXT
========================================================= */

function setText(element, value) {

    if (!element) {
        return;
    }


    element.textContent =
        value ?? "";

}


/* =========================================================
   29. HTML ESCAPING
========================================================= */

function escapeHTML(value) {

    if (
        value === null ||
        value === undefined
    ) {

        return "";

    }


    return String(value)

        .replace(
            /&/g,
            "&amp;"
        )

        .replace(
            /</g,
            "&lt;"
        )

        .replace(
            />/g,
            "&gt;"
        )

        .replace(
            /"/g,
            "&quot;"
        )

        .replace(
            /'/g,
            "&#039;"
        );

}


/* =========================================================
   30. ATTRIBUTE ESCAPING
========================================================= */

function escapeAttribute(value) {

    return escapeHTML(value);

}


/* =========================================================
   31. DOWNLOAD BUTTON PROTECTION
========================================================= */

if (elements.downloadButton) {

    elements.downloadButton.addEventListener(
        "click",
        event => {

            if (
                elements.downloadButton.classList.contains(
                    "disabled"
                )
            ) {

                event.preventDefault();

            }

        }
    );

}


/* =========================================================
   32. PAGE VISIBILITY
   Only refresh if cache is expired
========================================================= */

document.addEventListener(
    "visibilitychange",
    () => {

        if (
            document.visibilityState !== "visible"
        ) {
            return;
        }


        const now = Date.now();


        if (
            now - lastReleaseCheck >=
            RELEASE_CACHE_TIME
        ) {

            loadGitHubReleases();

        }

    }
);


/* =========================================================
   33. LIGHT PERIODIC CHECK
   Every 30 minutes instead of 10 minutes
========================================================= */

setInterval(
    () => {

        if (
            document.visibilityState !== "visible"
        ) {
            return;
        }


        loadGitHubReleases();

    },
    30 * 60 * 1000
);
