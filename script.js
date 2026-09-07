const GITHUB_OWNER = "Anshu101com";
const GITHUB_REPO = "mor-panchayat";


/* =========================================================
   2. GITHUB API
========================================================= */

const GITHUB_API =
    `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases`;

const GITHUB_RELEASES_PAGE =
    `https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases`;

const GITHUB_REPOSITORY_PAGE =
    `https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}`;


/* =========================================================
   3. DOM ELEMENTS
========================================================= */

const elements = {

    navbar:
        document.getElementById("navbar"),

    menuButton:
        document.getElementById("menuButton"),

    navLinks:
        document.getElementById("navLinks"),

    heroVersion:
        document.getElementById("heroVersion"),

    latestVersion:
        document.getElementById("latestVersion"),

    latestReleaseDescription:
        document.getElementById(
            "latestReleaseDescription"
        ),

    latestReleaseDate:
        document.getElementById(
            "latestReleaseDate"
        ),

    downloadVersion:
        document.getElementById(
            "downloadVersion"
        ),

    downloadDate:
        document.getElementById(
            "downloadDate"
        ),

    downloadFile:
        document.getElementById(
            "downloadFile"
        ),

    downloadButton:
        document.getElementById(
            "downloadButton"
        ),

    qrContainer:
        document.getElementById(
            "qrContainer"
        ),

    qrVersion:
        document.getElementById(
            "qrVersion"
        ),

    releasesList:
        document.getElementById(
            "releasesList"
        ),

    releasesError:
        document.getElementById(
            "releasesError"
        ),

    retryReleases:
        document.getElementById(
            "retryReleases"
        ),

    githubReleasesLink:
        document.getElementById(
            "githubReleasesLink"
        ),

    footerGithubLink:
        document.getElementById(
            "footerGithubLink"
        ),

    footerVersion:
        document.getElementById(
            "footerVersion"
        ),

    currentYear:
        document.getElementById(
            "currentYear"
        ),

    backToTop:
        document.getElementById(
            "backToTop"
        )

};


/* =========================================================
   4. GLOBAL STATE
========================================================= */

let releases = [];

let latestRelease = null;

let latestAPK = null;


/* =========================================================
   5. INITIALIZATION
========================================================= */

document.addEventListener(
    "DOMContentLoaded",
    () => {

        initializeWebsite();

    }
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
   6. CURRENT YEAR
========================================================= */

function setCurrentYear() {

    if (!elements.currentYear) {
        return;
    }

    elements.currentYear.textContent =
        new Date().getFullYear();

}


/* =========================================================
   7. NAVIGATION
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
                elements.navLinks.classList.toggle(
                    "open"
                );

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
        elements.navLinks.querySelectorAll(
            ".nav-link"
        );


    links.forEach(
        (link) => {

            link.addEventListener(
                "click",
                () => {

                    elements.navLinks.classList.remove(
                        "open"
                    );

                    elements.menuButton.classList.remove(
                        "open"
                    );

                    elements.menuButton.setAttribute(
                        "aria-expanded",
                        "false"
                    );

                }
            );

        }
    );

}


/* =========================================================
   8. SCROLL EFFECTS
========================================================= */

function setupScrollEffects() {

    updateNavbar();

    window.addEventListener(
        "scroll",
        () => {

            updateNavbar();

            updateActiveNavigation();

        },
        {
            passive: true
        }
    );

}


function updateNavbar() {

    if (!elements.navbar) {
        return;
    }

    if (window.scrollY > 25) {

        elements.navbar.classList.add(
            "scrolled"
        );

    } else {

        elements.navbar.classList.remove(
            "scrolled"
        );

    }

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


    let currentSection = "home";


    sections.forEach(
        (section) => {

            const rect =
                section.getBoundingClientRect();

            if (
                rect.top <= 160 &&
                rect.bottom >= 160
            ) {

                currentSection =
                    section.id;

            }

        }
    );


    links.forEach(
        (link) => {

            const href =
                link.getAttribute("href");


            link.classList.toggle(
                "active",
                href ===
                `#${currentSection}`
            );

        }
    );

}


/* =========================================================
   10. SMOOTH SCROLL
========================================================= */

function setupSmoothLinks() {

    document.querySelectorAll(
        'a[href^="#"]'
    ).forEach(
        (link) => {

            link.addEventListener(
                "click",
                (event) => {

                    const targetID =
                        link.getAttribute(
                            "href"
                        );


                    if (
                        !targetID ||
                        targetID === "#"
                    ) {
                        return;
                    }


                    const target =
                        document.querySelector(
                            targetID
                        );


                    if (!target) {
                        return;
                    }


                    event.preventDefault();


                    const navbarHeight =
                        elements.navbar
                            ? elements.navbar.offsetHeight
                            : 0;


                    const targetPosition =
                        target.getBoundingClientRect()
                            .top
                        +
                        window.scrollY
                        -
                        navbarHeight
                        -
                        10;


                    window.scrollTo({

                        top:
                            targetPosition,

                        behavior:
                            "smooth"

                    });

                }
            );

        }
    );

}


/* =========================================================
   11. BACK TO TOP
========================================================= */

function setupBackToTop() {

    if (!elements.backToTop) {
        return;
    }


    window.addEventListener(
        "scroll",
        () => {

            if (window.scrollY > 600) {

                elements.backToTop.classList.add(
                    "visible"
                );

            } else {

                elements.backToTop.classList.remove(
                    "visible"
                );

            }

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
        GITHUB_OWNER ===
        "YOUR_GITHUB_USERNAME" ||
        GITHUB_REPO ===
        "YOUR_REPOSITORY_NAME"
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

async function loadGitHubReleases() {

    if (
        GITHUB_OWNER ===
        "YOUR_GITHUB_USERNAME" ||
        GITHUB_REPO ===
        "YOUR_REPOSITORY_NAME"
    ) {

        showConfigurationError();

        return;

    }


    showReleaseLoading();


    try {

        const response =
            await fetch(
                GITHUB_API,
                {
                    headers: {
                        "Accept":
                            "application/vnd.github+json"
                    }
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
                        !release.draft
                )
                .sort(
                    sortReleases
                );


        if (releases.length === 0) {

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

    } catch (error) {

        console.error(
            "Mor Panchayat release loading error:",
            error
        );

        showReleaseError();

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
        !Array.isArray(
            release.assets
        )
    ) {
        return null;
    }


    const apkAssets =
        release.assets.filter(
            asset => {

                const name =
                    (
                        asset.name ||
                        ""
                    ).toLowerCase();


                return name.endsWith(
                    ".apk"
                );

            }
        );


    if (apkAssets.length === 0) {
        return null;
    }


    /*
       Prefer a release asset whose name
       contains "release" or "universal".
    */

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


    return preferred ||
        apkAssets[0];

}


/* =========================================================
   16. UPDATE LATEST RELEASE
========================================================= */

function updateLatestRelease() {

    if (!latestRelease) {
        return;
    }


    const version =
        getVersionName(
            latestRelease
        );


    const date =
        formatDate(
            latestRelease.published_at ||
            latestRelease.created_at
        );


    const description =
        getReleaseDescription(
            latestRelease
        );


    /*
       HERO
    */

    setText(
        elements.heroVersion,
        version
    );


    /*
       LATEST RELEASE CARD
    */

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


    /*
       DOWNLOAD CENTER
    */

    setText(
        elements.downloadVersion,
        version
    );


    setText(
        elements.downloadDate,
        date
    );


    /*
       FOOTER
    */

    setText(
        elements.footerVersion,
        version
    );


    /*
       QR
    */

    setText(
        elements.qrVersion,
        version
    );


    /*
       APK
    */

    if (latestAPK) {

        setText(
            elements.downloadFile,
            formatFileSize(
                latestAPK.size
            )
        );


        if (
            elements.downloadButton
        ) {

            elements.downloadButton.href =
                latestAPK.browser_download_url;

            elements.downloadButton.target =
                "_blank";

            elements.downloadButton.rel =
                "noopener noreferrer";


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


        if (
            elements.downloadButton
        ) {

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


    /*
       Prefer tag_name.

       Example:
       v1.0.7
    */

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

function getReleaseDescription(
    release
) {

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
                clean.substring(
                    0,
                    147
                ) +
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


    elements.releasesList.innerHTML = "";


    releases.forEach(
        (release, index) => {

            const version =
                getVersionName(
                    release
                );


            const date =
                formatDate(
                    release.published_at ||
                    release.created_at
                );


            const apk =
                findAPK(
                    release
                );


            const description =
                getReleaseDescription(
                    release
                );


            const item =
                document.createElement(
                    "article"
                );


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
                                target="_blank"
                                rel="noopener noreferrer"
                            >
                                ↓ Download
                            </a>
                        `
                        : `
                            <span
                                class="release-download"
                                style="
                                    opacity:0.45;
                                    cursor:not-allowed;
                                "
                            >
                                APK unavailable
                            </span>
                        `
                    }

                </div>

            `;


            elements.releasesList.appendChild(
                item
            );

        }
    );


    /*
       Animate release items
    */

    animateReleaseItems();

}


/* =========================================================
   20. ANIMATE RELEASE ITEMS
========================================================= */

function animateReleaseItems() {

    const items =
        document.querySelectorAll(
            ".release-item"
        );


    items.forEach(
        (item, index) => {

            item.style.opacity = "0";

            item.style.transform =
                "translateY(12px)";


            setTimeout(
                () => {

                    item.style.transition =
                        "opacity .45s ease, transform .45s ease";

                    item.style.opacity = "1";

                    item.style.transform =
                        "translateY(0)";

                },
                70 * index
            );

        }
    );

}


/* =========================================================
   21. QR CODE
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
       We use the QR Server API to generate
       the QR image dynamically.

       No QR library is required.
    */

    const qrURL =
        `https://api.qrserver.com/v1/create-qr-code/?size=500x500&margin=10&data=${encodeURIComponent(
            apkURL
        )}`;


    elements.qrContainer.innerHTML = `

        <img
            src="${escapeAttribute(qrURL)}"
            alt="QR code to download the latest Mor Panchayat APK"
            loading="lazy"
        >

    `;

}


/* =========================================================
   22. LOADING STATE
========================================================= */

function showReleaseLoading() {

    if (!elements.releasesList) {
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

        elements.releasesError.hidden =
            true;

    }

}


/* =========================================================
   23. ERROR STATE
========================================================= */

function showReleaseError() {

    if (elements.releasesList) {

        elements.releasesList.innerHTML = "";

    }


    if (elements.releasesError) {

        elements.releasesError.hidden =
            false;

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


    if (
        elements.latestReleaseDescription
    ) {

        elements.latestReleaseDescription.textContent =
            "Release information is temporarily unavailable.";

    }

}


/* =========================================================
   24. CONFIGURATION ERROR
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


    if (elements.heroVersion) {

        elements.heroVersion.textContent =
            "Configure GitHub";

    }

}


/* =========================================================
   25. RETRY BUTTON
========================================================= */

function setupRetryButton() {

    if (!elements.retryReleases) {
        return;
    }


    elements.retryReleases.addEventListener(
        "click",
        async () => {

            elements.releasesError.hidden =
                true;

            await loadGitHubReleases();

        }
    );

}


/* =========================================================
   26. DATE FORMAT
========================================================= */

function formatDate(
    dateString
) {

    if (!dateString) {
        return "Unknown";
    }


    const date =
        new Date(
            dateString
        );


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
   27. FILE SIZE
========================================================= */

function formatFileSize(
    bytes
) {

    if (
        typeof bytes !== "number" ||
        bytes <= 0
    ) {

        return "APK";

    }


    const MB =
        bytes /
        (1024 * 1024);


    if (MB < 1) {

        return (
            `${Math.round(
                bytes / 1024
            )} KB`
        );

    }


    return (
        `${MB.toFixed(1)} MB`
    );

}


/* =========================================================
   28. MARKDOWN CLEANER
========================================================= */

function stripMarkdown(
    text
) {

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
            /\!\[.*?\]\(.*?\)/g,
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
   29. SET TEXT SAFELY
========================================================= */

function setText(
    element,
    value
) {

    if (!element) {
        return;
    }


    element.textContent =
        value ?? "";

}


/* =========================================================
   30. HTML ESCAPING
========================================================= */

function escapeHTML(
    value
) {

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
   31. ATTRIBUTE ESCAPING
========================================================= */

function escapeAttribute(
    value
) {

    return escapeHTML(
        value
    );

}


/* =========================================================
   32. DOWNLOAD BUTTON PROTECTION
========================================================= */

if (elements.downloadButton) {

    elements.downloadButton.addEventListener(
        "click",
        (event) => {

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
   33. PAGE VISIBILITY REFRESH
=========================================================

   If the user leaves the page and returns,
   check GitHub again.

========================================================= */

document.addEventListener(
    "visibilitychange",
    () => {

        if (
            document.visibilityState ===
            "visible"
        ) {

            /*
               Small delay prevents unnecessary
               API calls during quick tab switching.
            */

            setTimeout(
                () => {

                    loadGitHubReleases();

                },
                500
            );

        }

    }
);


/* =========================================================
   34. PERIODIC RELEASE CHECK
=========================================================

   Check every 10 minutes.

========================================================= */

setInterval(
    () => {

        loadGitHubReleases();

    },
    10 * 60 * 1000
);
