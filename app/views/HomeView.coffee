require('app/styles/home-view.sass')
RootView = require 'views/core/RootView'
template = require 'templates/home-view'
CocoCollection = require 'collections/CocoCollection'
TrialRequest = require 'models/TrialRequest'
TrialRequests = require 'collections/TrialRequests'
Courses = require 'collections/Courses'
utils = require 'core/utils'
storage = require 'core/storage'
{logoutUser, me} = require('core/auth')
CreateAccountModal = require 'views/core/CreateAccountModal/CreateAccountModal'

#  TODO: auto margin feature paragraphs

module.exports = class HomeView extends RootView
  id: 'home-view'
  className: 'style-flat'
  template: template

  events:
    'click .open-video-btn': 'onClickOpenVideoButton'
    'click .play-btn': 'onClickPlayButton'
    'click .student-btn': 'onClickStudentButton'
    'click .teacher-btn': 'onClickTeacherButton'
    'click #learn-more-link': 'onClickLearnMoreLink'
    'click .screen-thumbnail': 'onClickScreenThumbnail'
    'click #carousel-left': 'onLeftPressed'
    'click #carousel-right': 'onRightPressed'
    'click .request-demo': 'onClickRequestDemo'
    'click .logout-btn': 'logoutAccount'
    'click .profile-btn': 'onClickViewProfile'
    'click .setup-class-btn': 'onClickSetupClass'
    'click .my-classes-btn': 'onClickMyClassesButton'
    'click .resource-btn': 'onClickResourceButton'
    'click a': 'onClickAnchor'

  shortcuts:
    'right': 'onRightPressed'
    'left': 'onLeftPressed'
    'esc': 'onEscapePressed'

  initialize: (options) ->
    @courses = new Courses()
    @supermodel.trackRequest @courses.fetchReleased()

    if me.isTeacher()
      @trialRequests = new TrialRequests()
      @trialRequests.fetchOwn()
      @supermodel.loadCollection(@trialRequests)

    @playURL = if me.isStudent()
      '/students'
    else
      '/play'

  onLoaded: ->
    @trialRequest = @trialRequests.first() if @trialRequests?.size()
    @isTeacherWithDemo = @trialRequest and @trialRequest.get('status') in ['approved', 'submitted']
    super()

  onClickOpenVideoButton: (event) ->
    unless @$('#screenshot-lightbox').data('bs.modal')?.isShown
      event.preventDefault()
      # Modal opening happens automatically from bootstrap
      @$('#screenshot-carousel').carousel($(event.currentTarget).data("index"))
    @vimeoPlayer.play()

  onCloseLightbox: ->
    @vimeoPlayer.pause()

  onClickLearnMoreLink: ->
    window.tracker?.trackEvent 'Homepage Click Learn More', category: 'Homepage', []
    @scrollToLink('#classroom-in-box-container')

  onClickPlayButton: (e) ->
    window.tracker?.trackEvent $(e.target).data('event-action'), category: 'Homepage', []

  onClickRequestDemo: (e) ->
    @playSound 'menu-button-click'
    e.preventDefault()
    e.stopImmediatePropagation()
    window.tracker?.trackEvent $(e.target).data('event-action'), category: 'Homepage', []
    if me.isTeacher()
      application.router.navigate '/teachers/update-account', trigger: true
    else
      application.router.navigate '/teachers/demo', trigger: true

  onClickSetupClass: (e) ->
    window.tracker?.trackEvent $(e.target).data('event-action'), category: 'Homepage', []
    application.router.navigate("/teachers/classes", { trigger: true })

  onClickStudentButton: (e) ->
    window.tracker?.trackEvent $(e.target).data('event-action'), category: 'Homepage', []
    @openModalView(new CreateAccountModal({startOnPath: 'student'}))

  onClickTeacherButton: (e) ->
    window.tracker?.trackEvent $(e.target).data('event-action'), category: 'Homepage', []
    @openModalView(new CreateAccountModal({startOnPath: 'teacher'}))

  onClickViewProfile: (e) ->
    e.preventDefault()
    window.tracker?.trackEvent $(e.target).data('event-action'), category: 'Homepage', []

  onClickMyClassesButton: (e) ->
    e.preventDefault()
    window.tracker?.trackEvent $(e.target).data('event-action'), category: 'Homepage', []

  onClickResourceButton: (e) ->
    e.preventDefault()
    window.tracker?.trackEvent $(e.target).data('event-action'), category: 'Homepage', []

  onClickAnchor: (e) ->
    return unless anchor = e?.currentTarget
    # Track an event with action of the English version of the link text
    translationKey = $(anchor).attr('data-i18n')
    translationKey ?= $(anchor).children('[data-i18n]').attr('data-i18n')
    if translationKey
      anchorText = $.i18n.t(translationKey, {lng: 'en-US'})
    else
      anchorText = anchor.text
    if anchorText
      window.tracker?.trackEvent "Link: #{anchorText}", category: 'Homepage', ['Google Analytics']

  afterRender: ->
    require.ensure(['@vimeo/player'], (require) =>
      Player = require('@vimeo/player').default
      @vimeoPlayer = new Player(@$('.vimeo-player')[0])
    , (e) =>
      console.log e
    , 'vimeo')
    @$('#screenshot-lightbox')
      .modal()
      .on 'hide.bs.modal', (e)=>
        @vimeoPlayer.pause()
      .on 'shown.bs.modal', (e)=>
        if @$('.video-carousel-item').hasClass('active')
          @vimeoPlayer.play()
    @$('#screenshot-carousel')
      .carousel({
        interval: 0
        keyboard: false
      })
      .on 'slide.bs.carousel', (e) =>
        if not $(e.relatedTarget).hasClass('.video-carousel-item')
          @vimeoPlayer.pause()
    if me.isAnonymous()
      if document.location.hash is '#create-account'
        @openModalView(new CreateAccountModal())
      if document.location.hash is '#create-account-individual'
        @openModalView(new CreateAccountModal({startOnPath: 'individual'}))
      if document.location.hash is '#create-account-student'
        @openModalView(new CreateAccountModal({startOnPath: 'student'}))
      if document.location.hash is '#create-account-teacher'
        @openModalView(new CreateAccountModal({startOnPath: 'teacher'}))
    super()

  afterInsert: ->
    super()
    # scroll to the current hash, once everything in the browser is set up
    f = =>
      return if @destroyed
      link = $(document.location.hash)
      if link.length
        @scrollToLink(document.location.hash, 0)
    _.delay(f, 100)

  destroy: ->
    # $(window).off 'resize', @fitToPage
    super()

  logoutAccount: ->
    Backbone.Mediator.publish("auth:logging-out", {})
    logoutUser()

  onRightPressed: (event) ->
    # Special handling, otherwise after you click the control, keyboard presses move the slide twice
    return if event.type is 'keydown' and $(document.activeElement).is('.carousel-control')
    if $('#screenshot-lightbox').data('bs.modal')?.isShown
      event.preventDefault()
      $('#screenshot-carousel').carousel('next')

  onLeftPressed: (event) ->
    return if event.type is 'keydown' and $(document.activeElement).is('.carousel-control')
    if $('#screenshot-lightbox').data('bs.modal')?.isShown
      event.preventDefault()
      $('#screenshot-carousel').carousel('prev')

  onEscapePressed: (event) ->
    if $('#screenshot-lightbox').data('bs.modal')?.isShown
      event.preventDefault()
      $('#screenshot-lightbox').modal('hide')

  onClickScreenThumbnail: (event) ->
    unless $('#screenshot-lightbox').data('bs.modal')?.isShown
      event.preventDefault()
      # Modal opening happens automatically from bootstrap
      $('#screenshot-carousel').carousel($(event.currentTarget).data("index"))

  mergeWithPrerendered: (el) ->
    true
