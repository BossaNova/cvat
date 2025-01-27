// Copyright (C) 2020-2022 Intel Corporation
//
// SPDX-License-Identifier: MIT

import React from 'react';
import PropTypes from 'prop-types';

import { connect } from 'react-redux';
import { CombinedState, ContextMenuType, Workspace } from 'reducers';

import CanvasContextMenuComponent from 'components/annotation-page/canvas/canvas-context-menu';
import { updateAnnotationsAsync, updateCanvasContextMenu } from 'actions/annotation-actions';
import { reviewActions, finishIssueAsync } from 'actions/review-actions';
import { ThunkDispatch } from 'utils/redux';
import { ObjectState } from 'cvat-core-wrapper';

interface OwnProps {
    readonly: boolean;
}

interface StateToProps {
    contextMenuParentID: number | null;
    contextMenuClientIDs: number[];
    objectStates: any[];
    collapsedStates: Record<number, boolean>;
    visible: boolean;
    top: number;
    left: number;
    type: ContextMenuType;
    labels: any[];
    collapsed: boolean | undefined;
    workspace: Workspace;
    latestComments: string[];
}

interface DispatchToProps {
    onStartIssue(position: number[]): void;
    updateState(objectStates: any[]): void;
    openIssue(position: number[], message: string): void;
}

function mapStateToProps(state: CombinedState): StateToProps {
    const {
        annotation: {
            annotations: { collapsed, states: objectStates },
            canvas: {
                contextMenu: {
                    visible, top, left, type, clientIDs, parentID,
                },
                ready,
            },
            job: { labels },
            workspace,
        },
        review: { latestComments },
    } = state;

    let objectState = objectStates.find((_state: ObjectState) => {
        if (Number.isInteger(parentID)) return _state.clientID === parentID;
        return clientIDs.includes(_state.clientID);
    });
    if (Number.isInteger(parentID) && objectState) {
        objectState = objectState.elements.find((_state: ObjectState) => clientIDs.includes(_state.clientID));
    }

    return {
        contextMenuClientIDs: clientIDs,
        contextMenuParentID: parentID,
        collapsed: clientIDs.length === 1 ? collapsed[clientIDs[0]] : undefined,
        collapsedStates: state.annotation.annotations.collapsed,
        objectStates,
        labels,
        visible:
            clientIDs.length > 0 &&
            visible &&
            ready &&
            !!objectState,
        left,
        top,
        type,
        workspace,
        latestComments,
    };
}

function mapDispatchToProps(dispatch: ThunkDispatch): DispatchToProps {
    return {
        onStartIssue(position: number[]): void {
            dispatch(reviewActions.startIssue(position));
            dispatch(updateCanvasContextMenu(false, 0, 0));
        },
        updateState(states: any[]): void {
            dispatch(updateAnnotationsAsync(states));
        },
        openIssue(position: number[], message: string): void {
            dispatch(reviewActions.startIssue(position));
            dispatch(finishIssueAsync(message));
            dispatch(updateCanvasContextMenu(false, 0, 0));
        },
    };
}

type Props = StateToProps & DispatchToProps & OwnProps;

interface State {
    latestLeft: number;
    latestTop: number;
    left: number;
    top: number;
}

class CanvasContextMenuContainer extends React.PureComponent<Props, State> {
    static propTypes = {
        readonly: PropTypes.bool,
    };

    static defaultProps = {
        readonly: false,
    };

    private initialized: HTMLDivElement | null;
    private dragging: boolean;
    private dragInitPosX: number;
    private dragInitPosY: number;

    public constructor(props: Props) {
        super(props);

        this.initialized = null;
        this.dragging = false;
        this.dragInitPosX = 0;
        this.dragInitPosY = 0;
        this.state = {
            latestLeft: 0,
            latestTop: 0,
            left: 0,
            top: 0,
        };
    }

    static getDerivedStateFromProps(props: Props, state: State): State | null {
        if (props.left === state.latestLeft && props.top === state.latestTop) {
            return null;
        }

        return {
            ...state,
            latestLeft: props.left,
            latestTop: props.top,
            top: props.top,
            left: props.left,
        };
    }

    public componentDidMount(): void {
        this.updatePositionIfOutOfScreen();
        window.addEventListener('mousemove', this.moveContextMenu);
    }

    public componentDidUpdate(prevProps: Props): void {
        const { collapsed } = this.props;

        const [element] = window.document.getElementsByClassName('cvat-canvas-context-menu');
        if (collapsed !== prevProps.collapsed && element) {
            element.addEventListener(
                'transitionend',
                () => {
                    this.updatePositionIfOutOfScreen();
                },
                { once: true },
            );
        } else if (element) {
            this.updatePositionIfOutOfScreen();
        }

        if (element && (!this.initialized || this.initialized !== element)) {
            this.initialized = element as HTMLDivElement;

            this.initialized.addEventListener('mousedown', (e: MouseEvent): any => {
                this.dragging = true;
                this.dragInitPosX = e.clientX;
                this.dragInitPosY = e.clientY;
            });

            this.initialized.addEventListener('mouseup', () => {
                this.dragging = false;
            });
        }
    }

    public componentWillUnmount(): void {
        window.removeEventListener('mousemove', this.moveContextMenu);
    }

    private moveContextMenu = (e: MouseEvent): void => {
        if (this.dragging) {
            this.setState((state) => {
                const value = {
                    left: state.left + e.clientX - this.dragInitPosX,
                    top: state.top + e.clientY - this.dragInitPosY,
                };

                this.dragInitPosX = e.clientX;
                this.dragInitPosY = e.clientY;

                return value;
            });

            e.preventDefault();
        }
    };

    private updatePositionIfOutOfScreen(): void {
        const { top, left } = this.state;
        const { innerWidth, innerHeight } = window;

        const [element] = window.document.getElementsByClassName('cvat-canvas-context-menu');
        if (element) {
            const height = element.clientHeight;
            const width = element.clientWidth;

            if (top + height > innerHeight || left + width > innerWidth) {
                this.setState({
                    top: top - Math.max(top + height - innerHeight, 0),
                    left: left - Math.max(left + width - innerWidth, 0),
                });
            }
        }
    }

    public render(): JSX.Element {
        const { left, top } = this.state;
        const {
            visible,
            contextMenuClientIDs,
            contextMenuParentID,
            objectStates,
            collapsedStates,
            labels,
            type,
            readonly,
            workspace,
            latestComments,
            onStartIssue,
            openIssue,
            updateState,
        } = this.props;

        return (
            <>
                {type === ContextMenuType.CANVAS_SHAPE && (
                    <CanvasContextMenuComponent
                        contextMenuClientIDs={contextMenuClientIDs}
                        contextMenuParentID={contextMenuParentID}
                        readonly={readonly}
                        collapsedStates={collapsedStates}
                        left={left}
                        top={top}
                        visible={visible}
                        objectStates={objectStates}
                        labels={labels}
                        workspace={workspace}
                        latestComments={latestComments}
                        onStartIssue={onStartIssue}
                        openIssue={openIssue}
                        updateState={updateState}
                    />
                )}
            </>
        );
    }
}

export default connect(mapStateToProps, mapDispatchToProps)(CanvasContextMenuContainer);
