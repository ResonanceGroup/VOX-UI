# Tech Context

## Technologies Used
- **UltraVox Client SDK:** For voice processing and interaction
- **n8n:** For backend workflow automation and webhook integration
- **HTML, CSS, JavaScript:** For building the front-end web application
- **CSS Features:**
  - CSS Grid and Flexbox for responsive layouts
  - CSS Transitions and Animations for smooth interactions
  - CSS Variables for consistent theming
  - CSS Transforms for element positioning
  - Backdrop filters for overlay effects

## Development Setup
- The project will be developed in a Windows 11 environment
- The default shell is PowerShell
- The project is located in the `a:/Software/VOX-UI` directory
- Project structure:
  - `src/`: Source files for the web application
  - `cline_docs/`: Documentation and memory bank
  - `Images/`: Image assets

## Technical Constraints
- The UltraVox Client SDK is a key dependency and must be properly integrated
- The front-end must be responsive and work on both desktop and mobile browsers
- The animated orb must be performant and visually appealing
- The webhook integration with n8n must be reliable and efficient

## UI Implementation Details
- **Responsive Design:**
  - Mobile-first approach with breakpoints at 600px
  - Consistent 60px heights for header and input areas
  - Flexible container widths with max-width constraints
  - Touch-optimized button sizes and spacing

- **Component Architecture:**
  - Modular CSS with component-specific styles
  - Reusable button and input styles
  - Consistent spacing and sizing variables
  - State-based styling with CSS classes

- **Animation System:**
  - CSS transitions for UI state changes
  - CSS animations for continuous effects
  - Hardware-accelerated transforms
  - Optimized performance with opacity and transform properties

- **Interactive Elements:**
  - Popup sidebar menu with overlay
  - Toggle states for mute functionality
  - Text input with upload and send capabilities
  - Hover and active states for all buttons
